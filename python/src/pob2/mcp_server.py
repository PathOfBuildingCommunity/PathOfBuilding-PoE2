"""MCP server exposing a live Path of Building 2 build to AI agents.

Run:  uv run --directory python pob2-mcp        (stdio transport)
      uv run --directory python pob2-mcp --http (streamable HTTP on 127.0.0.1:8765/mcp)
"""

from __future__ import annotations

import argparse
import functools
import logging
import sys
from typing import Annotated, Any

import httpx
from mcp.server.mcpserver import MCPServer
from mcp.server.mcpserver.exceptions import ToolError
from mcp.types import ToolAnnotations
from pydantic import Field

from pob2.codec import CodecError
from pob2.engine import EngineError
from pob2.service import PoBService

log = logging.getLogger("pob2.mcp")

INSTRUCTIONS = """\
Path of Building 2 (Path of Exile 2 build planner) running headless. One build is active at a time.
Typical flow: load_build (share code / pobb.in link / XML) or new_build -> get_build_overview ->
inspect with get_stats, list_skills, list_items, get_passive_tree -> evaluate changes with
compare_item / compare_passives BEFORE applying them with equip_item / allocate_passives ->
export_build to hand the result back as a share code.
Stat values are PoB's calculated numbers for the current configuration (see list_config);
enemy conditions and buffs in the config strongly affect DPS.
"""

mcp = MCPServer("pob2-enhanced", title="Path of Building 2", instructions=INSTRUCTIONS, version="0.1.0")
_service: PoBService | None = None

READ = ToolAnnotations(readOnlyHint=True, idempotentHint=True, openWorldHint=False)
WRITE = ToolAnnotations(readOnlyHint=False, destructiveHint=False, openWorldHint=False)
REPLACE = ToolAnnotations(readOnlyHint=False, destructiveHint=True, openWorldHint=False)

NodeIds = Annotated[list[int], Field(description="Passive node ids (from search_passives or get_passive_tree)")]


def tool(annotations: ToolAnnotations) -> Any:
    """Register a tool, surfacing engine/codec errors to the agent as readable tool errors."""

    def decorator(fn: Any) -> Any:
        @functools.wraps(fn)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            try:
                return fn(*args, **kwargs)
            except (EngineError, CodecError, httpx.HTTPError) as exc:
                raise ToolError(str(exc)) from exc

        return mcp.tool(annotations=annotations)(wrapper)

    return decorator


def svc() -> PoBService:
    global _service
    if _service is None:
        _service = PoBService()
    return _service


# -- build -----------------------------------------------------------------------------------------


@tool(REPLACE)
def load_build(
    source: Annotated[str, Field(description="PoB share code, pobb.in/pastebin/poe.ninja link, or build XML")],
) -> dict[str, Any]:
    """Load a build, replacing the active one. Returns basic build info."""
    return svc().load(source)


@tool(REPLACE)
def new_build(
    class_name: Annotated[str | None, Field(description="e.g. Witch, Ranger, Warrior, Sorceress")] = None,
    ascendancy: Annotated[str | None, Field(description="e.g. Infernalist, Deadeye")] = None,
    level: Annotated[int | None, Field(ge=1, le=100)] = None,
) -> dict[str, Any]:
    """Start an empty build, replacing the active one."""
    return svc().new_build(class_name, ascendancy, level)


@tool(READ)
def get_build_overview() -> dict[str, Any]:
    """Class, level, main skill, sidebar stats, skill groups, equipped items and non-default config."""
    return svc().overview()


@tool(READ)
def export_build(include_xml: bool = False) -> dict[str, Any]:
    """Export the active build as a PoB share code (importable in Path of Building / pobb.in)."""
    result = svc().export()
    return result if include_xml else {"code": result["code"]}


@tool(WRITE)
def set_character(
    level: Annotated[int | None, Field(ge=1, le=100)] = None,
    class_name: str | None = None,
    ascendancy: str | None = None,
) -> dict[str, Any]:
    """Change character level, class or ascendancy. Changing class resets the passive tree."""
    return svc().set_character(level, class_name, ascendancy)


@tool(READ)
def list_classes() -> list[dict[str, Any]]:
    """All classes and their ascendancies."""
    return svc().call("data.classes")


# -- stats -----------------------------------------------------------------------------------------


@tool(READ)
def get_stats(
    keys: Annotated[
        list[str] | None,
        Field(description="Specific output keys, e.g. ['TotalDPS','Life','FireResist']. Omit for all scalar stats."),
    ] = None,
) -> dict[str, Any]:
    """Raw calculated output values for the current build and main skill."""
    return svc().call("stats.get", keys=keys)


@tool(READ)
def get_stat_summary() -> dict[str, Any]:
    """The formatted sidebar stats (DPS, defences, resistances, costs) as shown in PoB."""
    return svc().call("stats.summary")


# -- skills ----------------------------------------------------------------------------------------


@tool(READ)
def list_skills() -> list[dict[str, Any]]:
    """Skill groups (socket groups) with gems, which group is the main skill, and active skills."""
    return svc().call("skills.list")


@tool(WRITE)
def add_skill_group(
    gems: Annotated[
        list[str],
        Field(
            description="Gem names, active skill first then supports. "
            "Optionally 'Name level/quality', e.g. 'Fireball 20/0'"
        ),
    ],
    label: str | None = None,
    make_main: bool = True,
) -> dict[str, Any]:
    """Add a skill group. Unrecognised gem names are reported in 'warnings' with suggestions."""
    return svc().call("skills.add", gems=gems, label=label, makeMain=make_main)


@tool(WRITE)
def set_main_skill(
    group: Annotated[int, Field(description="Skill group index from list_skills")],
    skill: Annotated[int | None, Field(description="Active skill index within the group")] = None,
) -> dict[str, Any]:
    """Choose which skill group (and active skill) the DPS calculations are for."""
    return svc().call("skills.set_main", group=group, skill=skill)


@tool(WRITE)
def set_skill_group_enabled(group: int, enabled: bool) -> dict[str, Any]:
    """Enable or disable a skill group (e.g. toggle an aura or buff)."""
    return svc().call("skills.set_enabled", group=group, enabled=enabled)


@tool(ToolAnnotations(destructiveHint=True, openWorldHint=False))
def remove_skill_group(group: int) -> list[dict[str, Any]]:
    """Remove a skill group. Returns the remaining groups."""
    return svc().call("skills.remove", group=group)


@tool(READ)
def search_gems(query: str = "", support: bool | None = None, limit: int = 30) -> list[dict[str, Any]]:
    """Search skill and support gems by name or tag (e.g. 'fire', 'minion', 'projectile')."""
    return svc().call("data.gems", query=query, support=support, limit=limit)


# -- items -----------------------------------------------------------------------------------------


@tool(READ)
def list_items(include_mods: bool = True) -> list[dict[str, Any]]:
    """Equipped items by slot, including mod lines (with 'supported' = whether PoB models the mod)."""
    return svc().call("items.list", full=include_mods)


@tool(READ)
def list_item_slots() -> list[str]:
    """Valid slot names for equip_item / compare_item."""
    return svc().call("items.slots")


@tool(READ)
def compare_item(
    item_text: Annotated[str, Field(description="Item text as copied from the game (Ctrl+C) or PoB")],
    slot: Annotated[str | None, Field(description="Slot to compare against; defaults to the item's slot")] = None,
) -> dict[str, Any]:
    """What-if: stat changes if this item replaced the one in the slot. Does not modify the build."""
    return svc().call("stats.compare_item", text=item_text, slot=slot)


@tool(WRITE)
def equip_item(item_text: str, slot: str | None = None) -> dict[str, Any]:
    """Equip an item from its text. Defaults to the item's natural slot."""
    return svc().call("items.equip", text=item_text, slot=slot)


@tool(WRITE)
def unequip_item(slot: str) -> bool:
    """Empty an item slot."""
    return svc().call("items.unequip", slot=slot)


@tool(READ)
def parse_item(item_text: str) -> dict[str, Any]:
    """Parse item text and report which mods PoB supports, without equipping it."""
    return svc().call("items.parse", text=item_text)


@tool(READ)
def search_uniques(query: str = "", item_type: str | None = None, limit: int = 30) -> list[dict[str, Any]]:
    """Search the unique item database by name or base (item_type e.g. 'Helmet', 'Wand')."""
    return svc().call("data.uniques", query=query, type=item_type, limit=limit)


@tool(READ)
def get_unique(name: str) -> dict[str, Any]:
    """Full item text of a unique, usable with compare_item / equip_item."""
    return svc().call("data.unique", name=name)


@tool(READ)
def search_item_bases(query: str = "", item_type: str | None = None, limit: int = 30) -> list[dict[str, Any]]:
    """Search item base types (for writing rare item text)."""
    return svc().call("data.bases", query=query, type=item_type, limit=limit)


# -- passive tree ----------------------------------------------------------------------------------


@tool(READ)
def get_passive_tree() -> dict[str, Any]:
    """Allocated passive nodes with their stats, and points used."""
    return svc().call("tree.get")


@tool(READ)
def search_passives(
    query: Annotated[str, Field(description="Text in node name or stats, e.g. 'spell damage', 'Raw Destruction'")],
    include_minor: Annotated[bool, Field(description="Include small (non-notable) nodes")] = False,
    limit: int = 25,
) -> list[dict[str, Any]]:
    """Find passive nodes. pathLength = points needed to reach an unallocated node."""
    return svc().call("tree.search", query=query, includeMinor=include_minor, limit=limit)


@tool(READ)
def compare_passives(add: NodeIds | None = None, remove: NodeIds | None = None) -> dict[str, Any]:
    """What-if: stat changes from allocating (including path) and/or removing nodes. No changes made."""
    return svc().call("stats.compare_nodes", add=add, remove=remove)


@tool(WRITE)
def allocate_passives(ids: NodeIds) -> dict[str, Any]:
    """Allocate nodes, pathing through the shortest route. Unreachable ids are listed in 'failed'."""
    return svc().call("tree.allocate", ids=ids)


@tool(WRITE)
def deallocate_passives(ids: NodeIds) -> dict[str, Any]:
    """Deallocate nodes and everything that depends on them."""
    return svc().call("tree.deallocate", ids=ids)


@tool(WRITE)
def import_tree_url(url: str) -> dict[str, Any]:
    """Replace the passive tree from a pathofexile.com passive tree URL."""
    return svc().call("tree.import_url", url=url)


# -- configuration ---------------------------------------------------------------------------------


@tool(READ)
def list_config(
    query: Annotated[str | None, Field(description="Filter by label or variable, e.g. 'shock', 'boss'")] = None,
    include_hidden: Annotated[bool, Field(description="Include options not relevant to this build")] = False,
) -> list[dict[str, Any]]:
    """Configuration options (enemy state, buffs, conditions, charges) with current values."""
    return svc().call("config.list", query=query, all=include_hidden)


@tool(WRITE)
def set_config(
    values: Annotated[dict[str, Any], Field(description="{var: value} using 'var' names from list_config")],
) -> dict[str, Any]:
    """Change configuration options and recalculate."""
    return svc().call("config.set", values=values)


@tool(WRITE)
def set_custom_mods(
    text: Annotated[str, Field(description="One modifier per line, e.g. '+20% to Fire Resistance'")],
) -> dict[str, Any]:
    """Replace the build's custom modifiers (Config tab) to model effects PoB cannot parse elsewhere."""
    return svc().call("config.custom_mods", text=text)


# -- resources & prompts ---------------------------------------------------------------------------


@mcp.resource("pob://build/code", mime_type="text/plain")
def build_code() -> str:
    """Share code of the active build."""
    return svc().export()["code"]


@mcp.resource("pob://build/xml", mime_type="application/xml")
def build_xml() -> str:
    """Full XML of the active build."""
    return svc().export()["xml"]


@mcp.prompt()
def analyze_build(code: str) -> str:
    """Review a build: strengths, weaknesses and prioritised upgrades."""
    return (
        f"Load this Path of Building 2 build with load_build, then call get_build_overview.\n\n{code}\n\n"
        "Review offence and defence (resistances, max hit taken, EHP, recovery). Identify the top 5 "
        "weaknesses, and for each propose a concrete change. Validate every proposal with compare_item "
        "or compare_passives and report the measured deltas. Do not apply changes."
    )


@mcp.prompt()
def optimize_passives(goal: str = "more DPS without losing life", points: int = 5) -> str:
    """Find the best passive nodes for a goal within a point budget."""
    return (
        f"Goal: {goal}. Budget: {points} passive points.\n"
        "Use search_passives to find candidate notables, compare_passives to measure each (note pathLength), "
        "rank by gain per point, and present a plan. Ask before calling allocate_passives."
    )


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="PoB2-Enhanced MCP server")
    parser.add_argument("--http", action="store_true", help="Serve streamable HTTP instead of stdio")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--eager", action="store_true", help="Start the PoB engine immediately")
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, stream=sys.stderr, format="%(levelname)s %(name)s: %(message)s")
    if args.eager:
        svc().engine.start()
    if args.http:
        mcp.run(transport="streamable-http", host=args.host, port=args.port)
    else:
        mcp.run()


if __name__ == "__main__":
    main()
