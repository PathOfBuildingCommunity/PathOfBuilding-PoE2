"""从已提交源码构建 Windows 多语言便携发行包。"""

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from update_manifest import manifest_paths


def stage_files(source: Path, staged: Path) -> set[str]:
    """按更新清单的同一规则组装便携目录，返回运行时文件名。"""
    config = configparser.ConfigParser()
    config.read(source / 'manifest.cfg', encoding='utf-8')
    runtime_files = set()
    destinations = set()
    for section, path, relative in manifest_paths(source, config):
        destination = Path(str(relative).replace('{space}', ' '))
        name = destination.as_posix()
        if name.casefold() in destinations:
            raise RuntimeError(f'分发路径冲突：{name}')
        destinations.add(name.casefold())
        target = staged / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / path, target)
        if section == 'runtime':
            runtime_files.add(name)
    return runtime_files


def run(*args: str, cwd: Path) -> str:
    # 子进程失败立即终止，避免将构建不完整的文件作为发行包。
    return subprocess.check_output(args, cwd=cwd, text=True, encoding="utf-8", errors="replace").strip()


def package(version: str, repository: str, output: Path) -> None:
    # 只接受明确的版本与仓库标识，发布 URL 不随当前分支变化。
    if not re.fullmatch(r"\d+\.\d+\.\d+-multilingual\.\d+", version):
        raise ValueError("版本格式必须为 0.23.1-multilingual.1")
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository):
        raise ValueError("仓库格式必须为 owner/repository")
    root = Path(__file__).resolve().parents[1]
    if run("git", "status", "--porcelain", cwd=root):
        raise RuntimeError("请先提交工作区改动，再从干净源码构建")
    commit = run("git", "rev-parse", "HEAD", cwd=root)
    output.mkdir(parents=True, exist_ok=False)
    tag = "v" + version
    name = f"PathOfBuilding-PoE2-{tag}-windows-portable.zip"
    base_url = f"https://github.com/{repository}/releases/download/{tag}/"
    with tempfile.TemporaryDirectory(prefix="pob2-release-") as temporary:
        temporary = Path(temporary)
        archive = temporary / "source.zip"
        run("git", "archive", "--format=zip", f"--output={archive}", "HEAD", cwd=root)
        source = temporary / "source"
        with zipfile.ZipFile(archive) as source_zip:
            source_zip.extractall(source)
        environment = os.environ.copy()
        environment.pop("NOTO_SANS_SC_FONT", None)
        subprocess.run(["cmd.exe", "/d", "/c", "build.cmd"], cwd=source, env=environment, check=True)
        staged = temporary / "portable"
        staged.mkdir()
        runtime_files = stage_files(source, staged)
        readme = f"""Path of Building (PoE2) {version} — Windows portable prerelease
Source commit: {commit}
Release: https://github.com/{repository}/releases/tag/{tag}

使用说明
1. 将整个 ZIP 解压到有写入权限的目录，不要直接在压缩包中运行。
2. 双击 Path of Building-PoE2.exe，无需安装编译器、Python 或 Node.js。
3. 在 Options 中选择 English、简体中文或繁體中文，然后保存设置。
4. 构筑和设置保存在解压目录；升级时先备份 Builds 与 Settings.xml。
5. 此预发布固定到本次发布的完整性检查源；获取新版请重新下载完整 ZIP。
日语和韩语目前只有语言入口及字体支持，正文回退英文。

Instructions
Extract the complete ZIP to a writable folder, then run Path of Building-PoE2.exe.
Choose English, Simplified Chinese or Traditional Chinese in Options and save.
Builds and Settings.xml stay in the extracted folder. Back them up before upgrading.
This prerelease checks integrity against this release only; download a new ZIP to upgrade.
Japanese and Korean currently fall back to English text.
Font files and their OFL notices are included; no system font installation is required.
"""
        (staged / "README-PORTABLE.txt").write_text(readme, encoding="utf-8")
        (staged / "release.json").write_text(json.dumps({"version": version, "commit": commit, "repository": repository}, indent=2) + "\n", encoding="utf-8")
        manifest = ET.Element("PoBVersion")
        ET.SubElement(manifest, "Version", number=version, branch=tag, platform="win32")
        ET.SubElement(manifest, "Source", part="default", url=base_url)
        ET.SubElement(manifest, "Source", part="program", url=base_url + name)
        ET.SubElement(manifest, "Source", part="runtime", platform="win32", url=base_url + name)
        files = sorted(path for path in staged.rglob("*") if path.is_file())
        for path in files:
            relative = path.relative_to(staged).as_posix()
            attributes = {"name": relative, "part": "runtime" if relative in runtime_files else "program", "sha1": hashlib.sha1(path.read_bytes()).hexdigest()}
            if relative in runtime_files:
                attributes["platform"] = "win32"
            ET.SubElement(manifest, "File", attributes)
        ET.indent(manifest, "\t")
        ET.ElementTree(manifest).write(staged / "manifest.xml", encoding="utf-8", xml_declaration=True)
        shutil.copyfile(staged / "manifest.xml", output / "manifest.xml")
        with zipfile.ZipFile(output / name, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as portable_zip:
            for path in sorted(staged.rglob("*")):
                if path.is_file():
                    portable_zip.write(path, path.relative_to(staged).as_posix())
        with zipfile.ZipFile(output / name) as portable_zip:
            if portable_zip.testzip() is not None:
                raise RuntimeError("ZIP 完整性验证失败")
            extracted = temporary / 'extracted'
            portable_zip.extractall(extracted)
        environment['POB_PACKAGED_TEST_USER'] = str(temporary / 'font-cache')
        subprocess.run([str(source / 'tools/LuaRunner.exe'),
                        str(source / 'src/Tests/LocalisationPackagedFonts.lua'), str(extracted)],
                       cwd=extracted, env=environment, check=True)
        for language in ('ja-JP', 'ko-KR'):
            subprocess.run([sys.executable, str(source / 'tools/check-atlas.py'), '--folder',
                            str(temporary / 'font-cache/Path of Building (PoE2)/Fonts' / language)], check=True)
        checksums = []
        for path in (output / name, output / "manifest.xml"):
            checksums.append(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name)
        (output / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n", encoding="utf-8")
        subprocess.run([sys.executable, str(root / 'tools/check-release.py'), str(output)], check=True)
    print(f"Release {tag}: {commit}\n{output}\n" + "\n".join(checksums))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--repository", default="isWxiang/PathOfBuilding-PoE2")
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    package(arguments.version, arguments.repository, arguments.output.resolve())
