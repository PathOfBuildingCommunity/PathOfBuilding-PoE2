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
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP

import buildcode
from engine_client import EngineClient

mcp = FastMCP("path-of-building")
engine = EngineClient()


async def _call(cmd: str, **args: Any) -> Any:
    return await asyncio.to_thread(engine.request, cmd, **args)


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
    text = source.strip()
    if buildcode.looks_like_xml(text):
        xml = text
    elif os.path.isfile(text):
        with open(text, "r", encoding="utf-8") as fh:
            xml = fh.read()
    else:
        try:
            xml = buildcode.code_to_xml(text)
        except Exception as exc:  # noqa: BLE001
            raise ValueError(
                "source is not XML, an existing .xml path, or a valid build code"
            ) from exc
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
) -> dict:
    """Greedily allocate the best passive nodes one by one to maximise `metric`.

    Each step evaluates all reachable unallocated nodes within `max_depth` distance
    and picks the one with the highest gain to `metric` (e.g. "CombinedDPS",
    "FullDPS", "Life", "EnergyShield"). Repeats up to `budget` times. The entire
    run is saved as a single undo state so `undo_passive_changes` reverts all steps
    at once. Returns the sequence of allocations and final stats.
    """
    return await _call("optimize_tree", metric=metric, budget=budget, maxDepth=max_depth)


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


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
