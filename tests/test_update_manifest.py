import configparser
import pathlib
import xml.etree.ElementTree as Et

import update_manifest


def test_macos_runtime_platform_metadata(monkeypatch, tmp_path: pathlib.Path) -> None:
    manifest = tmp_path / "manifest.xml"
    manifest.write_text(
        "<?xml version='1.0' encoding='UTF-8'?>"
        "<PoBVersion><Version number='1.2.3' /></PoBVersion>",
        encoding="utf-8",
    )

    config = configparser.ConfigParser()
    config["runtime"] = {
        "path": "runtime",
        "exclude-files": "",
        "exclude-directories": "",
    }
    config["runtime-macos-arm64"] = {
        "path": "runtime-macos-arm64",
        "exclude-files": "",
        "exclude-directories": "",
    }
    with (tmp_path / "manifest.cfg").open("w", encoding="utf-8") as fh:
        config.write(fh)

    (tmp_path / "runtime").mkdir()
    (tmp_path / "runtime" / "host.exe").write_bytes(b"win")
    (tmp_path / "runtime-macos-arm64").mkdir()
    (tmp_path / "runtime-macos-arm64" / "PathOfBuilding-PoE2.app.zip").write_bytes(b"mac")

    monkeypatch.chdir(tmp_path)
    update_manifest.create_manifest()

    root = Et.parse(tmp_path / "manifest-updated.xml").getroot()
    sources = {(node.get("part"), node.get("platform")) for node in root.findall("Source")}
    files = {
        (node.get("name"), node.get("part")): node.get("runtime")
        for node in root.findall("File")
    }

    assert ("runtime", "win32") in sources
    assert ("runtime-macos-arm64", "macos-arm64") in sources
    assert files[("host.exe", "runtime")] == "win32"
    assert files[("PathOfBuilding-PoE2.app.zip", "runtime-macos-arm64")] == "macos-arm64"

