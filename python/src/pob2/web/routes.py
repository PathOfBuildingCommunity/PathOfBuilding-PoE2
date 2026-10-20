"""REST endpoints. Sync handlers run in FastAPI's threadpool; the engine serialises calls."""

from __future__ import annotations

from typing import Any, Literal

from fastapi import APIRouter, Query
from pydantic import BaseModel, Field

from pob2 import mcp_server

router = APIRouter()


def svc():  # noqa: ANN201 - shared with the MCP server so both see the same build
    return mcp_server.svc()


# -- models ----------------------------------------------------------------------------------------


class NewBuild(BaseModel):
    className: str | None = None
    ascendancy: str | None = None
    level: int | None = Field(None, ge=1, le=100)


class ImportBuild(BaseModel):
    source: str = Field(description="Share code, pobb.in/pastebin/poe.ninja link, or XML")


class Character(BaseModel):
    level: int | None = Field(None, ge=1, le=100)
    className: str | None = None
    ascendancy: str | None = None


class AddSkill(BaseModel):
    gems: list[str]
    label: str | None = None
    makeMain: bool = True


class SkillMain(BaseModel):
    skill: int | None = None


class SkillEnabled(BaseModel):
    enabled: bool


class ItemText(BaseModel):
    text: str
    slot: str | None = None


class NodeIds(BaseModel):
    ids: list[int]


class NodeCompare(BaseModel):
    add: list[int] | None = None
    remove: list[int] | None = None


class TreeUrl(BaseModel):
    url: str = Field(description="pathofexile2.com/game/passive-skill-tree/ link or its code")


class ConfigValues(BaseModel):
    values: dict[str, Any]


class CustomMods(BaseModel):
    text: str


class AttributeChange(BaseModel):
    id: int
    attribute: Literal["Strength", "Dexterity", "Intelligence"]


class AttributeChanges(BaseModel):
    changes: list[AttributeChange]


class GemChange(BaseModel):
    name: str | None = None
    level: int | None = Field(None, ge=1, le=40)
    quality: int | None = Field(None, ge=0, le=40)
    enabled: bool | None = None


class ItemCheck(BaseModel):
    text: str = Field(description="Item text copied from the game (Ctrl+C)")
    slot: str | None = Field(None, description="Slot to test in (default: where it does best)")


class ReferenceUpload(BaseModel):
    content: str = Field(description="Contents of a PoE2 BuildPlanner .build file (JSON)")


# -- build -----------------------------------------------------------------------------------------


@router.get("/health")
def health() -> dict[str, Any]:
    s = svc()
    return {"ok": True, "engineRunning": s.engine.running, "revision": s.revision}


@router.get("/revision")
def revision() -> dict[str, int]:
    return {"revision": svc().revision}


@router.get("/build")
def overview() -> dict[str, Any]:
    s = svc()
    return {**s.overview(), "revision": s.revision}


@router.post("/build/new")
def new_build(body: NewBuild) -> dict[str, Any]:
    return svc().new_build(body.className, body.ascendancy, body.level)


@router.post("/build/import")
def import_build(body: ImportBuild) -> dict[str, Any]:
    return svc().load(body.source)


@router.get("/build/export")
def export_build() -> dict[str, str]:
    return svc().export()


@router.post("/build/character")
def character(body: Character) -> dict[str, Any]:
    return svc().set_character(body.level, body.className, body.ascendancy)


@router.get("/classes")
def classes() -> Any:
    return svc().call("data.classes")


# -- stats -----------------------------------------------------------------------------------------


@router.get("/stats")
def stats(keys: list[str] | None = Query(None)) -> Any:
    return svc().call("stats.get", keys=keys)


@router.get("/stats/summary")
def stat_summary() -> Any:
    return svc().call("stats.summary")


# -- skills ----------------------------------------------------------------------------------------


@router.get("/skills")
def skills() -> Any:
    return svc().call("skills.list")


@router.post("/skills")
def add_skill(body: AddSkill) -> Any:
    return svc().call("skills.add", gems=body.gems, label=body.label, makeMain=body.makeMain)


@router.post("/skills/{group}/main")
def set_main(group: int, body: SkillMain) -> Any:
    return svc().call("skills.set_main", group=group, skill=body.skill)


@router.patch("/skills/{group}")
def set_enabled(group: int, body: SkillEnabled) -> Any:
    return svc().call("skills.set_enabled", group=group, enabled=body.enabled)


@router.delete("/skills/{group}")
def remove_skill(group: int) -> Any:
    return svc().call("skills.remove", group=group)


# -- items -----------------------------------------------------------------------------------------


@router.get("/items")
def items(includeEmpty: bool = False) -> Any:
    return svc().call("items.list", includeEmpty=includeEmpty)


@router.get("/items/slots")
def item_slots() -> Any:
    return svc().call("items.slots")


@router.post("/items/equip")
def equip(body: ItemText) -> Any:
    return svc().call("items.equip", text=body.text, slot=body.slot)


@router.post("/items/compare")
def compare_item(body: ItemText) -> Any:
    return svc().call("stats.compare_item", text=body.text, slot=body.slot)


@router.post("/items/parse")
def parse_item(body: ItemText) -> Any:
    return svc().call("items.parse", text=body.text)


@router.delete("/items/{slot}")
def unequip(slot: str) -> Any:
    return svc().call("items.unequip", slot=slot)


# -- tree ------------------------------------------------------------------------------------------


@router.get("/tree")
def tree() -> Any:
    return svc().call("tree.get")


@router.get("/tree/layout")
def tree_layout() -> Any:
    return svc().tree_layout()


@router.get("/tree/search")
def tree_search(q: str, minor: bool = False, limit: int = 25) -> Any:
    return svc().call("tree.search", query=q, includeMinor=minor, limit=limit)


@router.get("/tree/node/{node_id}")
def tree_node(node_id: int) -> Any:
    return svc().call("tree.node", id=node_id)


@router.post("/tree/allocate")
def allocate(body: NodeIds) -> Any:
    return svc().call("tree.allocate", ids=body.ids)


@router.post("/tree/deallocate")
def deallocate(body: NodeIds) -> Any:
    return svc().call("tree.deallocate", ids=body.ids)


@router.post("/tree/compare")
def compare_nodes(body: NodeCompare) -> Any:
    return svc().call("stats.compare_nodes", add=body.add, remove=body.remove)


@router.post("/tree/reset")
def reset_tree() -> Any:
    return svc().call("tree.reset")


@router.post("/tree/import-url")
def import_tree(body: TreeUrl) -> Any:
    return svc().call("tree.import_url", url=body.url)


@router.get("/tree/export-url")
def export_tree() -> Any:
    return svc().call("tree.export_url")


# -- config ----------------------------------------------------------------------------------------


@router.get("/config")
def config(q: str | None = None, all: bool = False) -> Any:  # noqa: A002
    return svc().call("config.list", query=q, all=all)


@router.patch("/config")
def set_config(body: ConfigValues) -> Any:
    return svc().call("config.set", values=body.values)


@router.get("/config/custom-mods")
def get_custom_mods() -> Any:
    return svc().call("config.custom_mods")


@router.put("/config/custom-mods")
def put_custom_mods(body: CustomMods) -> Any:
    return svc().call("config.custom_mods", text=body.text)


@router.post("/tree/attributes")
def set_attributes(body: AttributeChanges) -> Any:
    return svc().set_attributes([c.model_dump() for c in body.changes])


@router.get("/advisor")
def advisor(
    metric: Literal["balanced", "dps", "ehp"] = "balanced",
    level: int | None = Query(None, ge=1, le=100),
    limit: int = Query(10, ge=1, le=50),
) -> Any:
    return svc().advice(metric, level, limit)


@router.get("/build/source")
def build_source() -> Any:
    return svc().source_info()


@router.post("/build/refresh")
def refresh_build() -> Any:
    return svc().refresh()


@router.post("/skills/{group}/gems/{index}")
def set_gem(group: int, index: int, body: GemChange) -> Any:
    return svc().set_gem(group, index, **body.model_dump(exclude_none=True))


@router.get("/gems/advice")
def gems_advice(metric: Literal["balanced", "dps", "ehp"] = "balanced") -> Any:
    return svc().gems_advice(metric)


@router.get("/gear/slots")
def gear_slots() -> Any:
    return svc().gear_slots()


@router.get("/gear/slot")
def gear_slot(slot: str, metric: Literal["balanced", "dps", "ehp"] = "balanced", league: str | None = None) -> Any:
    return svc().gear_slot(slot, metric, league)


@router.get("/sockets")
def sockets(
    metric: Literal["balanced", "dps", "ehp"] = "balanced", slot: str | None = None, limit: int = Query(5, ge=1, le=50)
) -> Any:
    return svc().socket_advice(metric, slot, limit)


@router.get("/sockets/plan")
def sockets_plan(
    metric: Literal["balanced", "dps", "ehp"] = "balanced",
    maxSwaps: int = Query(8, ge=1, le=20),  # noqa: N803 - query parameter name
    minGain: float = Query(0.5, ge=0),  # noqa: N803
    keepUnmodelled: bool = True,  # noqa: N803
) -> Any:
    return svc().socket_plan(metric, maxSwaps, minGain, keepUnmodelled)


@router.get("/gear/uniques")
def gear_uniques(
    metric: Literal["balanced", "dps", "ehp"] = "balanced",
    league: str | None = None,
    maxPrice: float | None = Query(None, ge=0),  # noqa: N803 - query parameter name
) -> Any:
    return svc().gear_uniques(metric, league, maxPrice)


@router.get("/market/leagues")
def market_leagues() -> Any:
    from pob2 import market

    return {"leagues": market.leagues(), "default": svc().league()}


@router.get("/budget")
def budget() -> Any:
    return svc().budget()


@router.post("/items/check")
def check_item(body: ItemCheck) -> Any:
    return svc().check_item(body.text, body.slot)


# -- reference build -------------------------------------------------------------------------------


@router.get("/reference")
def reference() -> Any:
    return svc().reference_summary()


@router.put("/reference")
def set_reference(body: ReferenceUpload) -> Any:
    return svc().set_reference(body.content)


@router.delete("/reference")
def clear_reference() -> Any:
    svc().clear_reference()
    return {"ok": True}


@router.get("/reference/compare")
def reference_compare(level: int | None = Query(None, ge=1, le=100)) -> Any:
    return svc().reference_compare(level)


@router.get("/reference/impact")
def reference_impact(level: int | None = Query(None, ge=1, le=100), limit: int = Query(40, ge=1, le=200)) -> Any:
    return svc().reference_impact(level, limit)


@router.post("/reference/apply-tree")
def apply_reference_tree(level: int | None = Query(None, ge=1, le=100)) -> Any:
    return svc().apply_reference_tree(level)


# -- data ------------------------------------------------------------------------------------------


@router.get("/data/gems")
def gems(q: str = "", support: bool | None = None, limit: int = 30) -> Any:
    return svc().call("data.gems", query=q, support=support, limit=limit)


@router.get("/data/uniques")
def uniques(q: str = "", type: str | None = None, limit: int = 30) -> Any:  # noqa: A002
    return svc().call("data.uniques", query=q, type=type, limit=limit)


@router.get("/data/uniques/{name}")
def unique(name: str) -> Any:
    return svc().call("data.unique", name=name)


@router.get("/data/bases")
def bases(q: str = "", type: str | None = None, limit: int = 30) -> Any:  # noqa: A002
    return svc().call("data.bases", query=q, type=type, limit=limit)
