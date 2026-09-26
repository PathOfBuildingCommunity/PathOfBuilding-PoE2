"""Integration tests against the real PoB engine (LuaJIT worker)."""

import pytest

from pob2 import codec
from pob2.engine import EngineError

pytestmark = pytest.mark.engine

WAND = """Rarity: Rare
Test Wand
Attuned Wand
--------
Item Level: 80
--------
+80 to maximum Life
50% increased Spell Damage"""


@pytest.fixture
def witch(service):
    service.new_build("Witch", "Infernalist", 90)
    service.call("skills.add", gems=["Fireball"])
    return service


def test_new_build(witch):
    info = witch.info()
    assert info["className"] == "Witch"
    assert info["ascendClassName"] == "Infernalist"
    assert info["level"] == 90
    assert info["mainSkill"] == "Fireball"


def test_summary_has_dps(witch):
    rows = {r["stat"]: r for r in witch.call("stats.summary")["player"]}
    assert rows["TotalDPS"]["value"] > 0
    assert rows["Life"]["value"] > 0


def test_export_import_round_trip(witch):
    before = witch.call("stats.get", keys=["TotalDPS", "Life"])
    code = witch.export()["code"]
    witch.new_build()
    witch.load(code)
    assert witch.call("stats.get", keys=["TotalDPS", "Life"]) == pytest.approx(before)
    assert codec.decode_code(code).startswith("<?xml")


def test_compare_item_does_not_modify_build(witch):
    life = witch.call("stats.get", keys=["Life"])["Life"]
    result = witch.call("stats.compare_item", text=WAND)
    assert result["slot"] == "Weapon 1"
    changes = {c["stat"]: c for c in result["changes"]}
    assert changes["Life"]["delta"] > 0 and changes["Life"]["better"]
    assert witch.call("stats.get", keys=["Life"])["Life"] == life


def test_equip_and_unequip(witch):
    witch.call("items.equip", text=WAND)
    slots = {s["slot"]: s for s in witch.call("items.list")}
    assert slots["Weapon 1"]["item"]["baseName"] == "Attuned Wand"
    witch.call("items.unequip", slot="Weapon 1")
    assert all(s["slot"] != "Weapon 1" for s in witch.call("items.list"))


def test_tree_search_compare_allocate(witch):
    hits = witch.call("tree.search", query="Raw Destruction")
    node = next(n for n in hits if n["name"] == "Raw Destruction")
    preview = witch.call("stats.compare_nodes", add=[node["id"]])
    assert preview["pointDelta"] == node["pathLength"]
    dps = next(c for c in preview["changes"] if c["stat"] == "TotalDPS")
    tree = witch.call("tree.allocate", ids=[node["id"]])
    assert tree["failed"] == []
    assert tree["pointsUsed"] == node["pathLength"]
    assert witch.call("stats.get", keys=["TotalDPS"])["TotalDPS"] == pytest.approx(dps["after"])


def test_config_affects_dps(witch):
    base = witch.call("stats.get", keys=["TotalDPS"])["TotalDPS"]
    witch.call("config.set", values={"conditionEnemyShocked": True})
    assert witch.call("stats.get", keys=["TotalDPS"])["TotalDPS"] > base
    witch.call("config.set", values={"conditionEnemyShocked": False})


def test_unknown_gem_warns(service):
    service.new_build()
    group = service.call("skills.add", gems=["Fireball", "Definitely Not A Gem"])
    assert group["warnings"] and "Definitely Not A Gem" in group["warnings"][0]


def test_errors_are_reported(service):
    with pytest.raises(EngineError) as exc:
        service.call("items.parse", text="garbage")
    assert exc.value.code == "bad_request"
    with pytest.raises(EngineError) as exc:
        service.call("no.such_method")
    assert exc.value.code == "method_not_found"


def test_layout(service):
    layout = service.tree_layout()
    assert len(layout["nodes"]) > 1000
    ids = {n["id"] for n in layout["nodes"]}
    assert all(a in ids and b in ids for a, b in layout["edges"][:200])
