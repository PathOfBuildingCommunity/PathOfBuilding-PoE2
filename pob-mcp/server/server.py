"""Path of Building (PoE2) MCP server.

Exposes the headless PoB calculation engine to AI agents so they can analyze and
tune builds: read computed stats, rank passive-tree nodes by marginal value, and
run what-if comparisons without touching the PoB GUI.

The engine runs as a separate LuaJIT subprocess (see engine_client.py); a crash
there never affects the PoB application itself.
"""

from __future__ import annotations

import asyncio
import os
import socket as _socket
import time
import traceback
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP

import buildcode
from engine_client import EngineClient

mcp = FastMCP("path-of-building")
engine = EngineClient()

# In-memory snapshot registry: {name -> {xml, stats, created}}
# Persists for the lifetime of the MCP server process.
_snapshots: dict[str, dict] = {}


async def _call(cmd: str, **args: Any) -> Any:
    return await asyncio.to_thread(engine.request, cmd, **args)


def _source_to_xml(source: str) -> str:
    """Convert source (XML string / build code / file path) to raw XML."""
    text = source.strip()
    if buildcode.looks_like_xml(text):
        return text
    if os.path.isfile(text):
        with open(text, "r", encoding="utf-8") as fh:
            return fh.read()
    try:
        return buildcode.code_to_xml(text)
    except Exception as exc:
        raise ValueError(
            "source is not XML, an existing .xml path, or a valid build code"
        ) from exc


@mcp.tool()
async def diagnose_connection() -> dict:
    """Diagnose the connection to the PoB GUI bridge (port 12321).

    Returns detailed info about what's happening when connecting — use this
    if get_summary / other tools fail with 'not running' errors.
    """
    result: dict = {}
    # Raw TCP test
    try:
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        s.settimeout(1.0)
        s.connect(("127.0.0.1", 12321))
        s.settimeout(3.0)
        data = b""
        while b"\n" not in data:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk
        s.close()
        result["raw_tcp"] = "ok"
        result["raw_response"] = data.decode("utf-8", errors="replace").strip()
    except Exception as e:
        result["raw_tcp"] = f"FAILED: {e!r}"
        result["raw_traceback"] = traceback.format_exc()
    # EngineClient test
    from engine_client import _try_connect_gui
    try:
        t = _try_connect_gui()
        if t is not None:
            try:
                summary = t.request("list_state", what="summary")
                result["summary"] = summary
                result["engine_client"] = "ok"
            finally:
                t.close()
        else:
            result["engine_client"] = "returned None (connect failed silently)"
    except Exception as e:
        result["engine_client"] = f"FAILED: {e!r}"
        result["engine_traceback"] = traceback.format_exc()
    return result


@mcp.tool()
async def load_build(source: str, name: str = "MCP build") -> dict:
    """Load a build into the engine for analysis.

    `source` may be one of:
      - a raw PoB build XML document (starts with `<`),
      - a PoB share/build code (URL-safe base64 + zlib),
      - a path to a `.xml` build file saved by the PoB GUI.

    Returns a short summary (class, ascendancy, level, FullDPS, Life). Call this
    before any analysis tool. Loading replaces the previously loaded build.
    """
    xml = _source_to_xml(source)
    return await asyncio.to_thread(engine.load_xml, xml, name)


@mcp.tool()
async def get_stats(fields: Optional[list[str]] = None) -> dict:
    """Return computed stats for the loaded build.

    With no `fields`, returns the full flat stat table (offence, defence,
    attributes, charges, plus a `SkillDPS` breakdown array). Pass `fields` (e.g.
    ["FullDPS", "Life", "FireResist"]) to fetch only those keys.
    """
    return await _call("get_output", fields=fields)


@mcp.tool()
async def get_summary() -> dict:
    """Return a condensed snapshot of the loaded build with sanity warnings.

    Includes headline offence/defence numbers and flags common problems such as
    elemental resistances below the 75% cap or low life.
    """
    o = await _call("get_output")
    keys = [
        "FullDPS", "TotalDPS", "CombinedDPS", "Life", "EnergyShield", "Mana",
        "Ward", "Armour", "Evasion", "TotalEHP", "FireResist", "ColdResist",
        "LightningResist", "ChaosResist", "BlockChance", "SpellBlockChance",
        "MeleeEvadeChance", "Str", "Dex", "Int",
    ]
    snapshot = {k: o[k] for k in keys if k in o}
    warnings: list[str] = []
    for res in ("FireResist", "ColdResist", "LightningResist"):
        val = o.get(res)
        if isinstance(val, (int, float)) and val < 75:
            warnings.append(f"{res} is {val:.0f}%, below the 75% cap")
    life = o.get("Life")
    es = o.get("EnergyShield", 0) or 0
    if isinstance(life, (int, float)) and (life + es) < 2000:
        warnings.append(f"low effective pool: Life {life:.0f} + ES {es:.0f}")
    snapshot["warnings"] = warnings
    return snapshot


@mcp.tool()
async def rank_passive_nodes(
    metric: str = "FullDPS",
    max_depth: int = 6,
    limit: int = 25,
) -> dict:
    """Rank unallocated passive-tree nodes by how much they improve `metric`.

    For each reachable, unallocated node within `max_depth` skill points of the
    current tree, computes the change to `metric` (e.g. "FullDPS", "Life",
    "Evasion", "EnergyShield") if that node's modifiers were added. Returns the top
    `limit` nodes sorted by absolute gain, each with `delta` and `deltaPerPoint`
    (gain divided by points needed to reach it). Use this to decide what to take
    next. Larger `max_depth` is more thorough but slower.
    """
    return await _call("rank_nodes", metric=metric, maxDepth=max_depth, limit=limit)


@mcp.tool()
async def evaluate_change(
    add_nodes: Optional[list[int]] = None,
    remove_nodes: Optional[list[int]] = None,
    conditions: Optional[list[str]] = None,
    metrics: Optional[list[str]] = None,
    full_output: bool = False,
) -> dict:
    """Run a what-if calculation without modifying the loaded build.

    Provide passive node ids to add and/or remove (ids come from
    `rank_passive_nodes` or `list_state(what="nodes")`), and optionally extra
    `conditions` to enable. Returns base vs new values and the delta for each of
    `metrics` (default: FullDPS, TotalDPS, Life, EnergyShield, Mana). Set
    `full_output=True` to also get the full resulting stat table.
    """
    override: dict[str, Any] = {}
    if add_nodes:
        override["addNodes"] = add_nodes
    if remove_nodes:
        override["removeNodes"] = remove_nodes
    if conditions:
        override["conditions"] = conditions
    return await _call(
        "eval_override", override=override, metrics=metrics, fullOutput=full_output
    )


@mcp.tool()
async def set_config(key: str, value: Any) -> dict:
    """Set a build config option (ConfigTab input) and recalculate.

    This mutates the loaded build's configuration (e.g. enemy level, charge counts,
    buff toggles) and triggers a recalc. Common keys mirror the PoB Configuration
    tab, such as "enemyLevel", "conditionStationary", "usePowerCharges". Use
    `list_state(what="config")` to inspect current values.
    """
    return await _call("set_config", key=key, value=value)


@mcp.tool()
async def list_state(what: str = "summary") -> dict:
    """Inspect the loaded build's current state.

    `what` selects the view:
      - "summary": class, level, headline stats,
      - "nodes": allocated passive nodes (id + name),
      - "skills": socket groups and gems, with the main skill,
      - "items": equipped items per slot,
      - "config": current ConfigTab input values.
    """
    return await _call("list_state", what=what)


@mcp.tool()
async def allocate_nodes(node_ids: list[int]) -> dict:
    """Permanently allocate passive tree nodes in the loaded build and recalculate.

    `node_ids` is a list of node ids (integers) to allocate. Get candidate ids from
    `rank_passive_nodes` or `list_state(what="nodes")`. Nodes that are already
    allocated are reported in `alreadyAlloc` and silently skipped. Returns updated
    headline stats (FullDPS, CombinedDPS, Life, EnergyShield) after recalc.

    Call `save_build` afterwards to persist changes to a file the PoB GUI can load.
    """
    return await _call("allocate_nodes", ids=node_ids)


@mcp.tool()
async def deallocate_nodes(node_ids: list[int]) -> dict:
    """Permanently deallocate passive tree nodes in the loaded build and recalculate.

    `node_ids` is a list of node ids to remove. Nodes that are not currently allocated
    are reported in `notAlloc` and silently skipped. Returns updated headline stats
    after recalc.

    Call `save_build` afterwards to persist changes to a file the PoB GUI can load.
    """
    return await _call("deallocate_nodes", ids=node_ids)


@mcp.tool()
async def save_build(path: str) -> dict:
    """Export the current (possibly mutated) build to an XML file.

    Writes the full PoB2 XML to `path` so it can be loaded in the PoB GUI via
    File → Load Build. Overwrites the file if it already exists. Returns the path
    and the byte size written.

    Typical workflow:
      1. load_build("C:/.../<build>.xml")
      2. allocate_nodes([...]) / deallocate_nodes([...])
      3. save_build("C:/.../<build>.xml")   ← same path to overwrite
      4. In PoB GUI: Load Build → pick the file.
    """
    result = await _call("get_xml")
    xml: str = result["xml"]
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(xml)
    return {"path": path, "bytes": len(xml.encode("utf-8"))}


@mcp.tool()
async def get_build_code() -> dict:
    """Export the current build as a PoB share code (URL-safe base64+zlib).

    Returns the compact build code string you can paste into PoB (File → Import /
    Export Build → Import from Code) or share with others. The code encodes the
    full build XML.
    """
    result = await _call("get_xml")
    xml: str = result["xml"]
    code = buildcode.xml_to_code(xml)
    return {"code": code}


@mcp.tool()
async def optimize_tree(
    metric: str = "CombinedDPS",
    budget: int = 10,
    max_depth: int = 3,
    weights: Optional[dict[str, float]] = None,
    min_constraints: Optional[dict[str, float]] = None,
) -> dict:
    """Greedily allocate the best passive nodes one by one using BFS path evaluation.

    Each step evaluates reachable unallocated paths within `max_depth` distance
    (plus Notables/Keystones up to depth 8 as lookahead). The gain is measured for
    the ENTIRE PATH so the algorithm naturally avoids paths through useless nodes.

    **`weights`** — multi-metric normalised scoring. Instead of maximising a single
    stat, optimise a weighted combination. Each metric is normalised by its base
    value so different scales are comparable. Example: `{"CombinedDPS": 0.7,
    "Life": 0.3}` balances damage and survivability. When omitted, falls back to
    single-metric absolute delta on `metric`.

    **`min_constraints`** — hard floor on any stat. Steps that would push a metric
    below the threshold are skipped entirely. Example: `{"Life": 3000,
    "FireResist": 75}` ensures Life never drops below 3000 and fire resistance
    stays capped. The optimiser stops early if no candidate satisfies all constraints.

    Each step result includes `type` (Normal / Notable / Keystone). The entire run
    is saved as a single undo state so `undo_passive_changes` reverts all at once.
    """
    return await _call(
        "optimize_tree",
        metric=metric,
        budget=budget,
        maxDepth=max_depth,
        weights=weights,
        minConstraints=min_constraints,
    )


@mcp.tool()
async def set_gem_level(
    group: int,
    name: str,
    level: Optional[int] = None,
    quality: Optional[int] = None,
) -> dict:
    """Change the level and/or quality of a gem in a socket group and recalculate.

    `group` is the 1-based socket group index (use `list_state(what="skills")` to
    find it). `name` must match the gem's `nameSpec` exactly (e.g. "Fireball",
    "Increased Area of Effect"). At least one of `level` or `quality` must be
    provided.
    """
    if level is None and quality is None:
        raise ValueError("at least one of level or quality must be provided")
    return await _call("set_gem", group=group, name=name, level=level, quality=quality)


@mcp.tool()
async def undo_passive_changes() -> dict:
    """Undo the last passive tree change (allocate, deallocate, or optimize_tree).

    Each call to `allocate_nodes`, `deallocate_nodes`, or `optimize_tree` saves an
    undo state before making changes. This tool reverts to the previous state.
    Returns updated headline stats after undo.
    """
    return await _call("undo_tree")


@mcp.tool()
async def redo_passive_changes() -> dict:
    """Redo the last undone passive tree change.

    Restores the state that was reverted by `undo_passive_changes`. Returns updated
    headline stats after redo.
    """
    return await _call("redo_tree")


@mcp.tool()
async def equip_item(slot: str, item_text: str) -> dict:
    """Parse a raw item and equip it to a build slot, then recalculate.

    `slot` is the equipment slot name — use `list_state(what="items")` to see
    currently equipped items and valid slot names (e.g. "Helmet", "Body Armour",
    "Weapon 1", "Ring 1", "Amulet", "Belt", "Gloves", "Boots", "Flask 1"–"Flask 6").

    `item_text` is the raw item text as copied from Path of Exile (the full block
    starting with "Item Class:" or "Rarity:"). Returns updated headline stats after
    the item is equipped.
    """
    return await _call("equip_item", slot=slot, item_text=item_text)


@mcp.tool()
async def remove_item(slot: str) -> dict:
    """Remove the item currently equipped in `slot` and recalculate.

    Use `list_state(what="items")` to see which slots have items. The item stays in
    the build's item list but is no longer equipped. Returns updated headline stats.
    """
    return await _call("remove_item", slot=slot)


@mcp.tool()
async def get_item_details(slot: str) -> dict:
    """Return full details for the item equipped in `slot`.

    Returns the item's name, base, rarity, quality, raw text, and a `mods` list
    with each modifier line grouped by type (implicit, explicit, enchant, rune).
    Returns `{empty: true}` if the slot is unoccupied.
    """
    return await _call("get_item_details", slot=slot)


@mcp.tool()
async def evaluate_item_change(
    slot: str,
    item_text: str,
    metrics: Optional[list[str]] = None,
) -> dict:
    """Compute the stat delta of replacing the item in `slot` without mutating the build.

    Temporarily swaps the item, recalculates, records the deltas for each of `metrics`
    (default: FullDPS, TotalDPS, CombinedDPS, Life, EnergyShield, Mana), then
    restores the original item. Returns `{slot, newItemName, newItemRarity, deltas}`
    where each delta entry contains `{base, new, delta}`.
    """
    return await _call("eval_item_change", slot=slot, item_text=item_text, metrics=metrics)


@mcp.tool()
async def add_gem(
    group: int,
    gem_name: str,
    level: int = 1,
    quality: int = 0,
) -> dict:
    """Add a gem to a socket group and recalculate.

    `group` is the 1-based socket group index (use `list_state(what="skills")` to
    find it). `gem_name` must match the gem's name as it appears in PoB (e.g.
    "Fireball", "Magnified Effect"). Returns updated headline stats.
    """
    return await _call("add_gem", group=group, name=gem_name, level=level, quality=quality)


@mcp.tool()
async def remove_gem(group: int, gem_name: str) -> dict:
    """Remove a gem from a socket group and recalculate.

    `group` is the 1-based socket group index. `gem_name` must match the gem's
    `nameSpec` exactly (use `list_state(what="skills")` to verify). Returns updated
    headline stats.
    """
    return await _call("remove_gem", group=group, name=gem_name)


@mcp.tool()
async def toggle_gem(group: int, gem_name: str, enabled: bool) -> dict:
    """Enable or disable a gem in a socket group and recalculate.

    Useful for comparing builds with and without a support gem without removing it.
    `enabled=False` disables the gem (it stays in the group but contributes nothing).
    Returns updated headline stats.
    """
    return await _call("toggle_gem", group=group, name=gem_name, enabled=enabled)


@mcp.tool()
async def toggle_skill_group(group: int, enabled: bool) -> dict:
    """Enable or disable an entire socket group and recalculate.

    Disabling a group removes it from DPS and buff calculations without deleting it.
    Use `list_state(what="skills")` to find the group index. Returns updated headline stats.
    """
    return await _call("toggle_skill_group", group=group, enabled=enabled)


@mcp.tool()
async def set_main_skill(group: int) -> dict:
    """Set the active (main) socket group used for DPS calculations and recalculate.

    `group` is the 1-based index of the socket group to make primary
    (use `list_state(what="skills")` to find it). This is equivalent to clicking
    a skill group in the PoB Skills tab. Returns updated headline stats.
    """
    return await _call("set_main_skill", group=group)


@mcp.tool()
async def list_masteries(allocated_only: bool = False) -> dict:
    """List all mastery nodes on the passive tree with their available effects.

    Each mastery node entry includes: `nodeId`, `name`, `allocated` (bool),
    `selectedEffect` (currently chosen effect id, or null), and `effects` — an
    array of `{id, stats[]}` describing every choosable effect. Set
    `allocated_only=True` to skip unallocated mastery nodes and only show ones
    where a selection can be made.
    """
    return await _call("list_masteries", allocatedOnly=allocated_only)


@mcp.tool()
async def set_mastery(node_id: int, effect_id: int) -> dict:
    """Select a mastery effect for an allocated mastery node and recalculate.

    `node_id` is the mastery node's id (from `list_masteries`). `effect_id` is the
    id of the effect to assign (also from `list_masteries`). The node must already
    be allocated on the passive tree. Returns updated headline stats after the new
    effect is applied.
    """
    return await _call("set_mastery", nodeId=node_id, effectId=effect_id)


@mcp.tool()
async def get_node_info(node_ids: list[int]) -> dict:
    """Return detailed information about specific passive tree nodes.

    `node_ids` is a list of node ids (from `rank_passive_nodes`, `list_state`, or
    `list_masteries`). For each node returns: `id`, `name`, `type`
    (Normal/Notable/Keystone/Mastery/Socket), `allocated`, `stats` (array of human-
    readable modifier lines), `ascendancy` (name if it's an ascendancy node),
    `pathDist` (points needed to reach it).
    """
    return await _call("get_node_info", ids=node_ids)


@mcp.tool()
async def set_character(
    level: Optional[int] = None,
    class_name: Optional[str] = None,
    ascendancy: Optional[str] = None,
) -> dict:
    """Change the character's level, class, and/or ascendancy and recalculate.

    All parameters are optional — supply only what you want to change. `class_name`
    and `ascendancy` are matched case-insensitively (e.g. "witch", "Chronomancer").
    If you change `class_name`, the passive tree resets to the new class start.
    Returns the applied level, className, ascendancy, and updated headline stats.
    """
    return await _call(
        "set_character",
        level=level,
        className=class_name,
        ascendancy=ascendancy,
    )


@mcp.tool()
async def set_bandit(choice: str) -> dict:
    """Set the bandit quest choice and recalculate.

    `choice` is the bandit name as it appears in PoB (e.g. "None", "Oak",
    "Alira", "Kraityn"). Returns the applied bandit value and updated headline stats.
    """
    return await _call("set_bandit", choice=choice)


@mcp.tool()
async def set_pantheon(
    major: Optional[str] = None,
    minor: Optional[str] = None,
) -> dict:
    """Set the Pantheon god choices and recalculate.

    `major` and `minor` are the god names as they appear in PoB (e.g. "None",
    "Soul of the Brine King"). Both are optional — omit to leave unchanged.
    Returns the applied pantheon values and updated headline stats.
    """
    return await _call("set_pantheon", major=major, minor=minor)


# ---------------------------------------------------------------------------
# Snapshots — pure Python, no new Lua handlers required
# ---------------------------------------------------------------------------

_HEADLINE = ["FullDPS", "TotalDPS", "CombinedDPS", "Life", "EnergyShield",
             "Mana", "Ward", "Armour", "Evasion", "TotalEHP"]


@mcp.tool()
async def create_snapshot(name: str) -> dict:
    """Save the current build state as a named in-memory snapshot.

    Captures the full build XML and all computed stats. Snapshots persist for
    the lifetime of the MCP server process. Overwrites any existing snapshot
    with the same name. Returns a headline summary of the captured state.
    """
    xml_result = await _call("get_xml")
    stats = await _call("get_output")  # full stat table — stored for later comparison
    _snapshots[name] = {
        "xml": xml_result["xml"],
        "stats": stats,
        "created": time.time(),
    }
    headline = {k: stats[k] for k in _HEADLINE if k in stats}
    return {"name": name, "headline": headline, "totalStats": len(stats)}


@mcp.tool()
async def list_snapshots() -> dict:
    """List all saved snapshots with their headline stats.

    Returns an array of `{name, created, headline}` entries sorted by creation
    time (oldest first).
    """
    entries = []
    for name, snap in sorted(_snapshots.items(), key=lambda x: x[1]["created"]):
        headline = {k: snap["stats"][k] for k in _HEADLINE if k in snap["stats"]}
        entries.append({
            "name": name,
            "created": snap["created"],
            "headline": headline,
        })
    return {"snapshots": entries, "count": len(entries)}


@mcp.tool()
async def restore_snapshot(name: str) -> dict:
    """Restore the build to a previously saved snapshot and recalculate.

    Loads the snapshot's XML into the engine exactly as `load_build` would.
    All changes made after the snapshot was taken are discarded. Returns
    headline stats after restoration.
    """
    if name not in _snapshots:
        available = list(_snapshots.keys())
        raise ValueError(f"snapshot '{name}' not found. Available: {available}")
    return await asyncio.to_thread(engine.load_xml, _snapshots[name]["xml"], name)


@mcp.tool()
async def delete_snapshot(name: str) -> dict:
    """Delete a named snapshot from memory.

    Returns the remaining snapshot names.
    """
    if name not in _snapshots:
        raise ValueError(f"snapshot '{name}' not found")
    del _snapshots[name]
    return {"deleted": name, "remaining": list(_snapshots.keys())}


@mcp.tool()
async def compare_snapshots(
    name1: str,
    name2: Optional[str] = None,
    metrics: Optional[list[str]] = None,
) -> dict:
    """Compare two snapshots (or a snapshot vs the current build) by stats.

    `name1` is a saved snapshot. `name2` defaults to `"current"` — the live
    build without reloading. Provide a second snapshot name to compare two
    saved states. `metrics` filters which stats to include in the delta table
    (default: all headline stats). Each delta entry contains `{a, b, delta,
    pct}` where `pct` is the percentage change relative to `a`.
    """
    if name1 not in _snapshots:
        raise ValueError(f"snapshot '{name1}' not found")

    if metrics is None:
        metrics = _HEADLINE

    stats1 = _snapshots[name1]["stats"]

    if name2 is None or name2 == "current":
        stats2 = await _call("get_output")
        label2 = "current"
    elif name2 not in _snapshots:
        raise ValueError(f"snapshot '{name2}' not found")
    else:
        stats2 = _snapshots[name2]["stats"]
        label2 = name2

    deltas: dict = {}
    for m in metrics:
        a = float(stats1.get(m) or 0)
        b = float(stats2.get(m) or 0)
        if a == 0 and b == 0:
            continue
        pct = round((b - a) / a * 100, 2) if a != 0 else None
        deltas[m] = {"a": a, "b": b, "delta": round(b - a, 4), "pct": pct}

    return {"snapshot1": name1, "snapshot2": label2, "deltas": deltas}


# ---------------------------------------------------------------------------
# Detailed analysis
# ---------------------------------------------------------------------------

_DAMAGE_KEYS = [
    # Overall
    "FullDPS", "TotalDPS", "CombinedDPS", "AverageDamage", "AverageBurstDamage",
    # Per damage type (stored = pre-mitigation average hit)
    "PhysicalStoredCombinedAvg", "FireStoredCombinedAvg", "ColdStoredCombinedAvg",
    "LightningStoredCombinedAvg", "ChaosStoredCombinedAvg", "ElementalStoredCombinedAvg",
    # DoT
    "TotalDotDPS", "TotalDot", "PoisonDPS", "BleedDPS", "IgniteDPS",
    "BurningGroundDPS", "CausticGroundDPS", "DecayDPS",
    # Crit
    "CritChance", "CritMultiplier",
    # Hit / speed
    "HitChance", "Speed",
    # Penetration
    "PhysicalPenetration", "FirePenetration", "ColdPenetration",
    "LightningPenetration", "ChaosPenetration",
]

_DEFENSE_KEYS = [
    # Pools
    "Life", "LifeUnreserved", "EnergyShield", "Ward", "Mana", "ManaUnreserved",
    "Spirit", "TotalEHP",
    # Regen / recovery
    "LifeRegen", "EnergyShieldRecharge", "EnergyShieldRechargeDelay",
    "LifeLeechRate", "EnergyShieldLeechRate", "LifeOnHit", "EnergyShieldOnHit",
    # Physical mitigation
    "Armour", "Evasion", "PhysicalDamageReduction",
    "MeleeEvadeChance", "ProjectileEvadeChance", "SpellEvadeChance",
    # Block
    "BlockChance", "ProjectileBlockChance", "SpellBlockChance",
    "SpellProjectileBlockChance",
    # Resistances
    "FireResist", "ColdResist", "LightningResist", "ChaosResist",
    "FireResistTotal", "ColdResistTotal", "LightningResistTotal", "ChaosResistTotal",
    # Spell suppression
    "SpellSuppressionChance", "SpellSuppressionEffect",
    # Misc
    "StunAvoidChance", "StunThreshold",
]


@mcp.tool()
async def get_damage_breakdown() -> dict:
    """Return a structured damage breakdown for the active skill.

    Groups stats into: `overall` (FullDPS, TotalDPS, CombinedDPS, AverageDamage),
    `byType` (per-element stored hit averages), `dot` (DoT DPS values), `crit`
    (CritChance, CritMultiplier), `speed` (Speed, HitChance), and `penetration`.
    Only non-zero stats are included. Also returns the `SkillDPS` skill-by-skill
    breakdown array if available.
    """
    raw = await _call("get_output", fields=_DAMAGE_KEYS)

    def pick(*keys: str) -> dict:
        return {k: raw[k] for k in keys if raw.get(k)}

    result: dict[str, Any] = {
        "overall": pick("FullDPS", "TotalDPS", "CombinedDPS",
                        "AverageDamage", "AverageBurstDamage"),
        "byType": pick("PhysicalStoredCombinedAvg", "FireStoredCombinedAvg",
                       "ColdStoredCombinedAvg", "LightningStoredCombinedAvg",
                       "ChaosStoredCombinedAvg", "ElementalStoredCombinedAvg"),
        "dot": pick("TotalDotDPS", "TotalDot", "PoisonDPS", "BleedDPS",
                    "IgniteDPS", "BurningGroundDPS", "CausticGroundDPS", "DecayDPS"),
        "crit": pick("CritChance", "CritMultiplier"),
        "speed": pick("Speed", "HitChance"),
        "penetration": pick("PhysicalPenetration", "FirePenetration", "ColdPenetration",
                            "LightningPenetration", "ChaosPenetration"),
    }
    # Attach SkillDPS array from full output if present
    full = await _call("get_output", fields=None)
    if isinstance(full.get("SkillDPS"), list):
        result["skillDPS"] = full["SkillDPS"]
    return result


@mcp.tool()
async def get_defense_breakdown() -> dict:
    """Return a structured defense breakdown for the loaded build.

    Groups stats into: `pools` (Life, ES, Ward, Mana, TotalEHP), `recovery`
    (regen, leech, on-hit), `mitigation` (Armour, Evasion, PhysDmgReduction,
    evade chances), `block`, `resistances`, `suppression`, and `misc`.
    Only non-zero stats are included.
    """
    raw = await _call("get_output", fields=_DEFENSE_KEYS)

    def pick(*keys: str) -> dict:
        return {k: raw[k] for k in keys if raw.get(k)}

    return {
        "pools": pick("Life", "LifeUnreserved", "EnergyShield", "Ward",
                      "Mana", "ManaUnreserved", "Spirit", "TotalEHP"),
        "recovery": pick("LifeRegen", "EnergyShieldRecharge", "EnergyShieldRechargeDelay",
                         "LifeLeechRate", "EnergyShieldLeechRate",
                         "LifeOnHit", "EnergyShieldOnHit"),
        "mitigation": pick("Armour", "Evasion", "PhysicalDamageReduction",
                           "MeleeEvadeChance", "ProjectileEvadeChance", "SpellEvadeChance"),
        "block": pick("BlockChance", "ProjectileBlockChance",
                      "SpellBlockChance", "SpellProjectileBlockChance"),
        "resistances": pick("FireResist", "ColdResist", "LightningResist", "ChaosResist",
                            "FireResistTotal", "ColdResistTotal",
                            "LightningResistTotal", "ChaosResistTotal"),
        "suppression": pick("SpellSuppressionChance", "SpellSuppressionEffect"),
        "misc": pick("StunAvoidChance", "StunThreshold"),
    }


@mcp.tool()
async def compare_builds(
    source: str,
    metrics: Optional[list[str]] = None,
) -> dict:
    """Compare the current build against another build without permanently replacing it.

    `source` accepts the same formats as `load_build` (XML, build code, or file path).
    After the comparison the original build is restored. Returns `current` and `other`
    class/level summaries plus a `deltas` table with `{current, other, delta, pct}`
    for each metric (default: headline stats).
    """
    if metrics is None:
        metrics = _HEADLINE

    # Snapshot current state before doing anything
    current_xml_str = (await _call("get_xml"))["xml"]
    current_stats = await _call("get_output", fields=metrics)
    current_summary = await _call("list_state", what="summary")

    try:
        other_xml = _source_to_xml(source)
        await asyncio.to_thread(engine.load_xml, other_xml, "compare_builds_tmp")
        other_stats = await _call("get_output", fields=metrics)
        other_summary = await _call("list_state", what="summary")
    finally:
        # Always restore the original build
        await asyncio.to_thread(engine.load_xml, current_xml_str, "restored")

    deltas: dict = {}
    for m in metrics:
        a = float(current_stats.get(m) or 0)
        b = float(other_stats.get(m) or 0)
        if a == 0 and b == 0:
            continue
        pct = round((b - a) / a * 100, 2) if a != 0 else None
        deltas[m] = {"current": a, "other": b, "delta": round(b - a, 4), "pct": pct}

    return {
        "current": {
            "class": current_summary.get("className"),
            "ascendancy": current_summary.get("ascendancy"),
            "level": current_summary.get("level"),
        },
        "other": {
            "class": other_summary.get("className"),
            "ascendancy": other_summary.get("ascendancy"),
            "level": other_summary.get("level"),
        },
        "deltas": deltas,
    }


@mcp.tool()
async def list_flasks() -> dict:
    """Return the state of all flask slots with full flask details.

    For each slot (`"Flask 1"`, `"Flask 2"`) returns: `slot`, `active` (bool —
    whether the flask is enabled for calculations), `empty`, and — when a flask
    is equipped — `name`, `rarity`, `flask` (base data: subType, life/mana
    recovery, duration, charges), and `flaskData` (computed effect values).
    """
    return await _call("list_flasks")


@mcp.tool()
async def toggle_flask(slot: str, active: bool) -> dict:
    """Enable or disable a flask for build calculations and recalculate.

    `slot` must be `"Flask 1"` or `"Flask 2"`. Setting `active=True` includes
    the flask's bonuses and modifiers in the DPS/defence calculation — equivalent
    to having the flask active in-game. Returns updated headline stats.
    """
    return await _call("toggle_flask", slot=slot, active=active)


@mcp.tool()
async def list_keystones(max_depth: Optional[int] = None) -> dict:
    """List keystone passive nodes — allocated and reachable ones on the tree.

    Returns every keystone with: `id`, `name`, `allocated`, `pathDist`, and
    `stats` (array of readable modifier lines). Allocated keystones are listed
    first, then sorted by proximity. Set `max_depth` to limit unallocated
    keystones to those within that many points of the current tree (useful for
    showing only realistic targets).
    """
    return await _call("list_keystones", maxDepth=max_depth)


@mcp.tool()
async def set_node_stat(node_id: int, index: int, stat: str) -> dict:
    """Permanently replace one stat line on a passive tree node and recalculate.

    This is a **mutating** operation — it modifies the node in the live build.
    Use `evaluate_node_stat` if you only want a what-if preview without changing
    the build.

    Args:
        node_id: Numeric node ID (from `rank_passive_nodes`, `get_node_info`, etc.).
        index:   1-based position in the node's stat list (`sdOriginal` from
                 `get_node_info`). For example, index=1 is the first stat line.
        stat:    New stat text exactly as PoB understands it, e.g.
                 `"20% increased maximum Life"` or `"+30 to Strength"`.

    Returns:
        `nodeId`, `name`, `index`, `oldStat`, `newStat`, and `stats` dict with
        headline metrics after the change (FullDPS, CombinedDPS, Life,
        EnergyShield, Armour, Evasion).
    """
    return await _call("set_node_stat", nodeId=node_id, index=index, stat=stat)


@mcp.tool()
async def evaluate_node_stat(
    node_id: int,
    overrides: dict[str, str],
) -> dict:
    """What-if: preview the effect of different stat lines on a passive node.

    Non-mutating — the build is left exactly as it was. Internally the engine
    modifies `node.sd`, calls `PassiveTree:ProcessStats` to rebuild the node's
    modifier list, recalculates, captures the output, then restores everything.

    Args:
        node_id:   Numeric node ID.
        overrides: Mapping of stat-line index (as a string, e.g. `"1"`) to the
                   replacement stat text.  Example:
                   `{"1": "30% increased maximum Life"}` to preview doubling a
                   "+15% maximum Life" node.  Unspecified lines are unchanged.

    Returns:
        `nodeId`, `name`, `nodeType`, `sdOriginal` (full original stat list),
        `before` and `after` dicts with the same set of headline metrics, and
        `delta` — only the stats that actually changed, each as
        `{before, after, diff}`.
    """
    return await _call("evaluate_node_stat", nodeId=node_id, overrides=overrides)


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
