#!/usr/bin/env python3
"""
Convert PoE2 0.5 passive tree data.json to 0.4-compatible format for PoB.
Usage: python convert_05_to_04.py <0.5_data.json> <0.4_tree.json> <output.json>

The 0.4 tree.json is needed to copy over assets/constants/nodeOverlay/connectionArt/ddsCoords
that were removed from the 0.5 schema but are still required by PoB's PassiveTree.lua parser.
"""
import json
import sys
import re

# 0.4-compatible options for generic attribute nodes. Every 0.5 isGenericAttribute
# node is a +5 STR/DEX/INT choice (confirmed by the raw "+5 to any Attribute" stat
# and matching 0.4's 293 identical attribute nodes). ids/values mirror the GGG
# export script's base_attributes (str 26297, dex 14927, int 57022); icons use the
# 0.5 .png paths that the icon extractor registers as assets.
ATTRIBUTE_OPTIONS = [
    {"id": 26297, "name": "Strength",     "icon": "Art/2DArt/SkillIcons/passives/plusstrength.png",     "stats": ["+5 to Strength"]},
    {"id": 14927, "name": "Dexterity",    "icon": "Art/2DArt/SkillIcons/passives/plusdexterity.png",    "stats": ["+5 to Dexterity"]},
    {"id": 57022, "name": "Intelligence", "icon": "Art/2DArt/SkillIcons/passives/plusintelligence.png", "stats": ["+5 to Intelligence"]},
]

def strip_stat_markup(stat_text):
    """Strip [Tag|Display] and <tag>{content} markup from stat text.
    [PuppetMaster|Puppet Master] -> Puppet Master
    [Command] -> Command (no display text, use tag as-is)
    <underline>{Hollow Focus} -> Hollow Focus
    """
    def replace_tag(m):
        tag = m.group(1)
        display = m.group(2)
        return display if display else tag
    # Strip [Tag|Display] markup
    result = re.sub(r'\[([^\]|]+)\|?([^\]]*)\]', replace_tag, stat_text)
    # Strip <tag>{content} markup -> content
    result = re.sub(r'<[^>]+>\{([^}]+)\}', r'\1', result)
    # Strip remaining <tag> and </tag>
    result = re.sub(r'</?[a-zA-Z]+>', '', result)
    return result

def build_ascendancy_id_to_name(classes):
    """Build mapping from ascendancyId (e.g. 'Ranger1') -> ascendancy name (e.g. 'Deadeye')"""
    mapping = {}
    for cls in classes:
        for asc in cls.get('ascendancies', []):
            if asc and asc.get('id') and asc.get('name'):
                mapping[asc['id']] = asc['name']
    return mapping

def build_class_index_to_name(classes):
    """Build mapping from class index -> class name"""
    return {i: cls['name'] for i, cls in enumerate(classes)}

def convert(new_data, old_data):
    out = {}

    # Copy static assets from 0.4 that 0.5 removed
    for key in ['assets', 'connectionArt', 'constants', 'ddsCoords', 'nodeOverlay']:
        if key in old_data:
            out[key] = old_data[key]

    # Copy bounds
    for key in ['min_x', 'min_y', 'max_x', 'max_y', 'tree']:
        out[key] = new_data[key]

    # Jewel slots
    out['jewelSlots'] = new_data.get('jewelSlots', [])

    # --- CLASSES ---
    asc_id_to_name = build_ascendancy_id_to_name(new_data['classes'])
    idx_to_name = build_class_index_to_name(new_data['classes'])

    converted_classes = []
    for i, cls in enumerate(new_data['classes']):
        new_cls = {
            'name': cls['name'],
            'base_str': cls.get('base_str', 0),
            'base_dex': cls.get('base_dex', 0),
            'base_int': cls.get('base_int', 0),
            'integerId': i,  # Synthesize integerId from array index
        }
        # Convert ascendancies
        new_ascs = []
        for asc in cls.get('ascendancies', []):
            if asc is None:
                continue
            # Skip unrevealed ascendancies (name=None)
            if not asc.get('name'):
                continue
            new_asc = {
                'id': asc.get('name', ''),        # 0.4 uses name as id
                'internalId': asc.get('id', ''),   # 0.4's internalId = 0.5's id
                'name': asc.get('name', ''),
            }
            new_ascs.append(new_asc)
        new_cls['ascendancies'] = new_ascs
        converted_classes.append(new_cls)

    out['classes'] = converted_classes

    # --- Build edges lookup for connections ---
    # 0.5 uses edges array + out/in on nodes
    # 0.4 uses connections array on each node: [{id: X, orbit: Y}, ...]
    # We need to convert out/in references to connections format

    # --- NODES ---
    converted_nodes = {}
    for nid, node in new_data['nodes'].items():
        if nid == 'root':
            continue  # Skip root pseudo-node

        new_node = {}

        # Direct copies
        for key in ['group', 'orbit', 'orbitIndex', 'icon', 'name', 'skill',
                     'isKeystone', 'isNotable', 'isJewelSocket', 'isMultipleChoice',
                     'isMultipleChoiceOption', 'isAscendancyStart',
                     'activeEffectImage', 'recipe',
                     'stats', 'unlockConstraint']:
            if key in node:
                new_node[key] = node[key]

        # Extract grantedSkill details and append to stats so they show in PoB tooltips
        if node.get('grantedSkill'):
            gs = node['grantedSkill']
            extra_stats = []
            # Skill name and description
            if gs.get('typeLine'):
                extra_stats.append(f"--- Granted Skill: {gs['typeLine']} ---")
            # Properties (cost, cast time, cooldown, etc.)
            for prop in gs.get('properties', []):
                if prop.get('values') and prop['values']:
                    extra_stats.append(f"{prop['name']}: {prop['values'][0][0]}")
            # Weapon requirements
            for req in gs.get('weaponRequirements', []):
                if req.get('values') and req['values']:
                    extra_stats.append(f"Requires: {req['values'][0][0]}")
            # Description
            if gs.get('secDescrText'):
                extra_stats.append(gs['secDescrText'])
            # Stats from gem tabs
            for tab in gs.get('gemTabs', []):
                tab_name = tab.get('name')
                for page in tab.get('pages', []):
                    skill_name = page.get('skillName', '')
                    if skill_name and tab_name != skill_name:
                        extra_stats.append(f"[{skill_name}]")
                    # Page properties
                    for prop in page.get('properties', []):
                        if prop.get('values') and prop['values']:
                            extra_stats.append(f"{prop['name']}: {prop['values'][0][0]}")
                    for stat in page.get('stats', []):
                        extra_stats.append(stat)
            # Append to existing stats
            if extra_stats:
                if 'stats' not in new_node:
                    new_node['stats'] = []
                new_node['stats'] = new_node['stats'] + extra_stats

        # Clean up all stat markup tags [Tag|Display] -> Display
        if 'stats' in new_node:
            new_node['stats'] = [strip_stat_markup(s) for s in new_node['stats']]

        # flavourText: 0.5 can have it as a table/object, PoB expects a string
        if 'flavourText' in node:
            ft = node['flavourText']
            if isinstance(ft, str):
                new_node['flavourText'] = strip_stat_markup(ft)
            elif isinstance(ft, dict):
                new_node['flavourText'] = strip_stat_markup(ft.get('text', str(ft)))
            elif isinstance(ft, list):
                new_node['flavourText'] = strip_stat_markup('\n'.join(str(x) for x in ft))
            else:
                new_node['flavourText'] = strip_stat_markup(str(ft))

        # Field renames
        if node.get('ascendancyId'):
            # Map ascendancyId -> ascendancyName using the name from the class data
            asc_name = asc_id_to_name.get(node['ascendancyId'])
            if not asc_name:
                # Unrevealed ascendancy — skip this node entirely
                continue
            new_node['ascendancyName'] = asc_name

        if node.get('classStartIndex') is not None:
            # Map class indices to class names
            names = [idx_to_name.get(idx, str(idx)) for idx in node['classStartIndex']]
            new_node['classesStart'] = names

        # 0.5 isGenericAttribute -> 0.4 isAttribute + options (the STR/DEX/INT chooser).
        # PassiveTree.lua's ProcessNode iterates node.options for isAttribute nodes.
        # isSwitchable is intentionally NOT set: the export script reserves that flag
        # for class/ascendancy override nodes, which use name-keyed options instead.
        if node.get('isGenericAttribute'):
            new_node['isAttribute'] = True
            new_node['options'] = [
                {"id": o["id"], "name": o["name"], "icon": o["icon"], "stats": list(o["stats"])}
                for o in ATTRIBUTE_OPTIONS
            ]

        if node.get('isFree'):
            new_node['isFreeAllocate'] = True

        if node.get('isJewelSocket'):
            new_node['containJewelSocket'] = True

        if node.get('isMastery'):
            new_node['isOnlyImage'] = True  # Masteries rendered as image nodes in 0.4

        # Connections: convert out[] to connections format
        connections = []
        for target in node.get('out', []):
            target_str = str(target)
            if target_str != 'root':
                connections.append({'id': int(target_str) if target_str.isdigit() else target, 'orbit': 0})
        new_node['connections'] = connections

        # nodeOverlay placeholder (0.5 doesn't have per-node overlays)
        # PassiveTree.lua will fall back to the global nodeOverlay

        converted_nodes[nid] = new_node

    out['nodes'] = converted_nodes

    # --- GROUPS ---
    # 0.4 uses a list (JSON array), 0.5 uses a dict (JSON object with string keys)
    # PoB expects array-indexed groups. Also convert node IDs from strings to ints.
    if isinstance(new_data.get('groups', {}), dict):
        # Convert dict to list, preserving order by numeric key
        max_key = max(int(k) for k in new_data['groups'].keys())
        groups_list = [None] * (max_key + 1)
        for gid, group in new_data['groups'].items():
            g = dict(group)
            # Convert node IDs from strings to ints
            g['nodes'] = [int(n) if isinstance(n, str) and n.isdigit() else n for n in g.get('nodes', [])]
            groups_list[int(gid)] = g
        # Remove None gaps — PoB iterates groups as an array
        out['groups'] = [g for g in groups_list if g is not None]
    else:
        out['groups'] = new_data.get('groups', [])

    return out

def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <0.5_data.json> <0.4_tree.json> <output_data.json>")
        sys.exit(1)

    new_path, old_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    print(f"Loading 0.5 data: {new_path}")
    with open(new_path) as f:
        new_data = json.load(f)

    print(f"Loading 0.4 reference: {old_path}")
    with open(old_path) as f:
        old_data = json.load(f)

    print("Converting...")
    result = convert(new_data, old_data)

    print(f"Writing: {out_path}")
    with open(out_path, 'w') as f:
        json.dump(result, f)

    print(f"Done. {len(result['nodes'])} nodes, {len(result['classes'])} classes.")
    for cls in result['classes']:
        ascs = [a['name'] for a in cls['ascendancies']]
        print(f"  {cls['name']}: {ascs if ascs else 'no ascendancies'}")

if __name__ == '__main__':
    main()
