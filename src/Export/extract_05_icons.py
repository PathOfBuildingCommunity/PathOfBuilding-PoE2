#!/usr/bin/env python3
"""
Extract PoE2 0.5 passive node icons from GGG's webp spritesheets and register
them in the converted tree data's `assets` table.

PoB's PassiveTree.lua resolves a node's art via GetAssetByName(node.icon), which
returns self.ddsMap[name] or self.assets[name]. Rather than repacking the 0.5
icons into the fork's grid-tiled .dds.zst format, this script extracts each icon
as an individual PNG and adds an `assets[node.icon] = { "icons/<file>.png" }`
entry, which LoadImage loads directly.

Usage:
    python extract_05_icons.py <ggg_assets_dir> <tree_data_json> <tree_dir>

    ggg_assets_dir  poe2-skilltree-export/assets  (has skills.webp + skills.json)
    tree_data_json  src/TreeData/0_5/data.json    (patched in place)
    tree_dir        src/TreeData/0_5              (icons written to <tree_dir>/icons/)
"""
import json
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: python -m pip install Pillow")

# Active-state spritesheets, in priority order. The active icons render at full
# luminance when allocated; PoB dims them for unallocated nodes at draw time, so
# we only need the active variants.
SHEETS = ["skills.webp"]
ATLASES = ["skills.json"]


def sanitize(icon_path):
    """Art/2DArt/SkillIcons/passives/damage.png -> passives_damage.png"""
    p = icon_path
    for prefix in ("Art/2DArt/SkillIcons/", "art/2dart/skillicons/"):
        if p.startswith(prefix):
            p = p[len(prefix):]
            break
    return p.replace("/", "_").replace(" ", "_").replace("\\", "_")


def load_frames(assets_dir):
    """Map icon path -> (atlas_image_file, frame dict), choosing the largest frame
    when an icon appears under multiple state prefixes."""
    best = {}  # path -> (area, image_file, frame)
    for atlas_name in ATLASES:
        atlas_path = os.path.join(assets_dir, atlas_name)
        if not os.path.isfile(atlas_path):
            continue
        atlas = json.load(open(atlas_path))
        image_file = atlas.get("meta", {}).get("image", atlas_name.replace(".json", ".webp"))
        for key, meta in atlas.get("frames", {}).items():
            path = key.split(":", 1)[1] if ":" in key else key
            f = meta.get("frame", {})
            area = f.get("w", 0) * f.get("h", 0)
            if path not in best or area > best[path][0]:
                best[path] = (area, image_file, f)
    return {p: (img, f) for p, (a, img, f) in best.items()}


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    assets_dir, data_path, tree_dir = sys.argv[1], sys.argv[2], sys.argv[3]

    data = json.load(open(data_path))
    icons = set()
    for n in data["nodes"].values():
        if not isinstance(n, dict):
            continue
        if n.get("icon"):
            icons.add(n["icon"])
        # Synthesized attribute nodes carry per-option icons that also need assets
        for opt in n.get("options", []) or []:
            if isinstance(opt, dict) and opt.get("icon"):
                icons.add(opt["icon"])
    node_icons = sorted(icons)
    print(f"Unique node icons: {len(node_icons)}")

    frames = load_frames(assets_dir)
    print(f"Atlas frames available: {len(frames)}")

    icons_out = os.path.join(tree_dir, "icons")
    os.makedirs(icons_out, exist_ok=True)

    # Cache decoded spritesheets
    sheets = {}

    def get_sheet(image_file):
        if image_file not in sheets:
            sheets[image_file] = Image.open(os.path.join(assets_dir, image_file)).convert("RGBA")
        return sheets[image_file]

    assets = data.setdefault("assets", {})
    extracted = 0
    missing = []
    for icon in node_icons:
        entry = frames.get(icon)
        if not entry:
            missing.append(icon)
            continue
        image_file, f = entry
        sheet = get_sheet(image_file)
        box = (f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])
        crop = sheet.crop(box)
        fname = sanitize(icon)
        crop.save(os.path.join(icons_out, fname))
        # assets value is a list whose [1] is the path relative to the tree dir
        assets[icon] = ["icons/" + fname]
        extracted += 1

    json.dump(data, open(data_path, "w"))
    print(f"Extracted {extracted} icons -> {icons_out}")
    print(f"Registered {extracted} assets entries in {data_path}")
    if missing:
        print(f"No atlas frame for {len(missing)} icons (left as-is):")
        for m in missing[:10]:
            print("   ", m)
        if len(missing) > 10:
            print(f"    ... and {len(missing) - 10} more")


if __name__ == "__main__":
    main()
