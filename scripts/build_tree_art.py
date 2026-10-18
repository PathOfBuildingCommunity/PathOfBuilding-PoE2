"""Convert PoE2 passive tree artwork (zstd-compressed DDS texture arrays) into WebP for the web UI.

    uv run --no-project --with zstandard --with texture2ddecoder --with pillow \
        python scripts/build_tree_art.py --out tree-art

Reads src/TreeData/<version>/tree.lua's ``ddsCoords`` (atlas file -> {asset name: layer index}) and writes
``<out>/<version>/manifest.json`` plus one WebP sprite sheet per small atlas or one WebP per layer for large
ones. Only atlases referenced by ``ddsCoords`` are converted. Defaults to the latest tree version.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import struct
import sys
from pathlib import Path

import texture2ddecoder
import zstandard
from PIL import Image

DXGI_BC1 = (70, 71, 72)
DXGI_BC7 = (97, 98, 99)
DXGI_RGBA = (27, 28, 29)
SHEET_MAX_SIDE = 256  # layers up to this size are packed into a sprite sheet
MAX_FILE_SIDE = 2048  # larger layers are downscaled (PoB draws them at 2x anyway)

ATLAS_RE = re.compile(r'^\t\t\["(.+?)"\]=\{\s*$')
ENTRY_RE = re.compile(r'^\t\t\t(?:\["(.+?)"\]|([A-Za-z_][A-Za-z0-9_]*))=(\d+),?\s*$')


def parse_dds_coords(tree_lua: Path) -> dict[str, dict[str, int]]:
    coords: dict[str, dict[str, int]] = {}
    inside = False
    current: dict[str, int] | None = None
    with tree_lua.open(encoding="utf-8") as f:
        for line in f:
            if not inside:
                inside = line.startswith("\tddsCoords={")
                continue
            if line.startswith("\t}"):
                break
            if m := ATLAS_RE.match(line):
                current = coords.setdefault(m.group(1), {})
            elif current is not None and (m := ENTRY_RE.match(line)):
                current[m.group(1) or m.group(2)] = int(m.group(3))
    return coords


def latest_version(root: Path) -> str:
    text = (root / "src" / "GameVersions.lua").read_text(encoding="utf-8")
    versions = re.search(r"treeVersionList\s*=\s*\{([^}]*)\}", text)
    if not versions:
        sys.exit("treeVersionList not found in GameVersions.lua")
    return re.findall(r'"([^"]+)"', versions.group(1))[-1]


def mip_bytes(w: int, h: int, dxgi: int) -> int:
    if dxgi in DXGI_RGBA:
        return w * h * 4
    block = 8 if dxgi in DXGI_BC1 else 16
    return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * block


def read_layers(path: Path, wanted: set[int] | None) -> tuple[int, int, dict[int, Image.Image]]:
    raw = zstandard.ZstdDecompressor().stream_reader(path.open("rb")).read()
    if raw[:4] != b"DDS ":
        raise ValueError(f"{path.name}: not a DDS file")
    height, width = struct.unpack_from("<2I", raw, 12)
    mips = max(1, struct.unpack_from("<I", raw, 28)[0])
    if raw[84:88] != b"DX10":
        raise ValueError(f"{path.name}: expected a DX10 texture array")
    dxgi, _, _, layers, _ = struct.unpack_from("<5I", raw, 128)
    offset = 148
    slice_size = sum(mip_bytes(max(1, width >> m), max(1, height >> m), dxgi) for m in range(mips))
    top = mip_bytes(width, height, dxgi)
    images: dict[int, Image.Image] = {}
    for layer in range(layers):
        index = layer + 1  # ddsCoords is 1-based
        if wanted is None or index in wanted:
            data = raw[offset : offset + top]
            if dxgi in DXGI_BC1:
                rgba = Image.frombytes(
                    "RGBA", (width, height), texture2ddecoder.decode_bc1(data, width, height), "raw", "BGRA"
                )
            elif dxgi in DXGI_BC7:
                rgba = Image.frombytes(
                    "RGBA", (width, height), texture2ddecoder.decode_bc7(data, width, height), "raw", "BGRA"
                )
            elif dxgi in DXGI_RGBA:
                rgba = Image.frombytes("RGBA", (width, height), data)
            else:
                raise ValueError(f"{path.name}: unsupported DXGI format {dxgi}")
            images[index] = rgba
        offset += slice_size
    return width, height, images


def convert_version(root: Path, version: str, out: Path) -> None:
    tree_dir = root / "src" / "TreeData" / version
    coords = parse_dds_coords(tree_dir / "tree.lua")
    if not coords:
        sys.exit(f"No ddsCoords in {tree_dir / 'tree.lua'}")
    dest = out / version
    dest.mkdir(parents=True, exist_ok=True)
    atlases: dict[str, dict] = {}
    names: dict[str, list[list]] = {}
    for file, entries in sorted(coords.items()):
        src = tree_dir / file
        if not src.is_file():
            print(f"  missing {file}, skipped", file=sys.stderr)
            continue
        atlas_id = file.removesuffix(".dds.zst")
        small = max(int(n) for n in re.findall(r"_(\d+)_(\d+)_", file)[0]) <= SHEET_MAX_SIDE
        w, h, images = read_layers(src, None if small else set(entries.values()))
        info: dict = {"w": w, "h": h}
        if small:
            count = max(images)
            cols = math.ceil(math.sqrt(count))
            sheet = Image.new("RGBA", (cols * w, math.ceil(count / cols) * h))
            for index, img in images.items():
                if index <= count:
                    sheet.paste(img, (((index - 1) % cols) * w, ((index - 1) // cols) * h))
            sheet.save(dest / f"{atlas_id}.webp", "WEBP", quality=92, method=4)
            info.update(kind="sheet", cols=cols)
        else:
            (dest / atlas_id).mkdir(exist_ok=True)
            for index, img in images.items():
                if max(w, h) > MAX_FILE_SIDE:
                    f = MAX_FILE_SIDE / max(w, h)
                    img = img.resize((round(w * f), round(h * f)), Image.LANCZOS)
                img.save(dest / atlas_id / f"{index}.webp", "WEBP", quality=85, method=2)
            info.update(kind="files")
        atlases[atlas_id] = info
        for name, index in entries.items():
            names.setdefault(name, []).append([atlas_id, index])
        print(f"  {atlas_id}: {len(entries)} assets, {w}x{h}, {info['kind']}")
    manifest = {"version": version, "atlases": atlases, "names": names}
    (dest / "manifest.json").write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1], help="Repository root")
    parser.add_argument("--out", type=Path, default=None, help="Output directory (default: <root>/tree-art)")
    parser.add_argument("--versions", nargs="*", help="Tree versions to convert (default: latest)")
    args = parser.parse_args()
    out = args.out or args.root / "tree-art"
    for version in args.versions or [latest_version(args.root)]:
        print(f"Tree {version}:")
        convert_version(args.root, version, out)


if __name__ == "__main__":
    main()
