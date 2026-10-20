"""Integration tests against the real PoB engine (LuaJIT worker)."""

import base64
import json

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


def test_tree_url_is_poe2_and_round_trips(witch):
    hits = witch.call("tree.search", query="Raw Destruction")
    witch.call("tree.allocate", ids=[next(n["id"] for n in hits if n["name"] == "Raw Destruction")])
    before = witch.call("tree.get")
    link = witch.call("tree.export_url")
    assert link["url"] == "https://pathofexile2.com/game/passive-skill-tree/" + link["code"]
    assert base64.urlsafe_b64decode(link["code"])[:4] == b"\x00\x00\x00\x07"
    witch.call("tree.reset")
    after = witch.call("tree.import_url", url=link["url"])
    assert after["className"] == before["className"] and after["ascendClassName"] == before["ascendClassName"]
    assert {n["id"] for n in after["nodes"]} == {n["id"] for n in before["nodes"]}


def test_tree_url_official_example(service):
    # Empty Druid tree from pathofexile2.com (class 11, first ascendancy).
    service.new_build()
    tree = service.call("tree.import_url", url="https://pathofexile2.com/game/passive-skill-tree/AAAABwsBAAA=")
    assert tree["className"] == "Druid" and tree["pointsUsed"] == 0


def test_tree_layout_has_artwork(service):
    layout = service.tree_layout()
    assert layout["classes"] and layout["ascendancies"]
    notable = next(n for n in layout["nodes"] if n["type"] == "Notable" and not n.get("ascendancy"))
    assert notable["icon"].endswith(".dds") and len(notable["frame"]) == 3 and notable["r"] > 0
    assert any(len(e) == 5 for e in layout["edges"])  # orbit arcs


def test_reference_build_compare_and_impact(witch):
    hits = witch.call("tree.search", query="Raw Destruction")
    witch.call("tree.allocate", ids=[next(n["id"] for n in hits if n["name"] == "Raw Destruction")])
    reference = {
        "name": "Test guide",
        "ascendancy": "Witch1",
        "passives": [],
        "skills": [
            {"id": "Metadata/Items/Gems/SkillGemFireball", "level_interval": [1, 100]},
            {"id": "Metadata/Items/Gems/SkillGemDefinitelyMissing", "level_interval": [1, 100]},
        ],
        "inventory_slots": [{"inventory_id": "Amulet1", "slot_x": 0, "additional_text": "<b>{Any} life amulet"}],
    }
    witch.set_reference(json.dumps(reference))
    cmp = witch.reference_compare()
    assert cmp["skills"][0]["name"] == "Fireball" and cmp["skills"][0]["found"]
    assert cmp["unknownGems"] == ["Metadata/Items/Gems/SkillGemDefinitelyMissing"]
    assert cmp["items"][0]["slot"] == "Amulet" and cmp["items"][0]["note"] == "Any life amulet"
    # The guide takes no passives, so everything allocated is "extra" and respeccing loses DPS.
    assert cmp["passives"]["extra"]
    impact = witch.reference_impact()
    assert impact["fullTree"]["removed"] > 0 and impact["fullTree"]["dpsPercent"] < 0
    witch.clear_reference()


def test_advisor_next_point_and_attributes(witch):
    advice = witch.advice()
    assert advice["mode"] == "free"
    step = advice["next"]
    assert step and step["path"][0] == step["first"]["id"] and step["path"][-1] == step["target"]["id"]
    assert step["reason"] and step["perPoint"] > 0

    # Allocate the nearest attribute node, then switch it and check the advice explains it.
    attr = min(
        (n for n in witch.call("tree.search", query="Attribute", includeMinor=True, limit=200) if n.get("isAttribute")),
        key=lambda n: n.get("pathLength") or 99,
    )
    witch.call("tree.allocate", ids=[attr["id"]])
    tree = witch.set_attributes([{"id": attr["id"], "attribute": "Intelligence"}])
    assert next(n for n in tree["nodes"] if n["id"] == attr["id"])["name"] == "Intelligence"
    entry = next(n for n in witch.advice()["attributes"]["nodes"] if n["id"] == attr["id"])
    assert entry["current"] == "Intelligence" and entry["reason"]


def test_gear_advice(witch):
    witch.call("items.equip", text=WAND)
    slots = {s["slot"]: s for s in witch.gear_slots()}
    assert "Weapon 1" in slots and "Helmet" in slots  # empty standard slots are evaluated too
    wand = witch.gear_slot("Weapon 1", league="Standard")
    assert wand["item"]["baseName"] == "Attuned Wand"
    life = next(m for m in wand["mods"] if "maximum Life" in m["text"])
    assert life["lifeDelta"] > 0 and not life.get("dead")
    assert wand["lookFor"] and wand["lookFor"][0]["percent"] > 0
    assert wand["tradeUrl"].startswith("https://www.pathofexile.com/trade2/search/poe2/Standard?q=")
    helmet = witch.gear_slot("Helmet")
    assert "item" not in helmet and helmet["testBase"] and helmet["headroom"] > 0


def test_gem_advice_and_set_gem(witch):
    advice = witch.gems_advice()
    fireball = next(g for g in advice["groups"] if "Fireball" in g["skills"])
    gem = next(x for x in fireball["gems"] if x["name"] == "Fireball")
    witch.set_gem(fireball["index"], gem["index"], level=1)
    advice = witch.gems_advice()
    assert any(u["kind"] == "level" and u["name"] == "Fireball" for u in advice["upgrades"])


def test_budget_and_item_check(witch):
    budget = witch.budget()
    assert {"spirit", "reserved", "free", "effectiveDps", "reservations"} <= budget.keys()
    check = witch.check_item(WAND)
    assert check["slot"] == "Weapon 1" and check["verdict"] in {"upgrade", "sidegrade", "downgrade"}
    fireball = next(s for s in check["skills"] if s["name"] == "Fireball")
    assert fireball["after"] >= fireball["before"] and fireball["isMain"]
    assert any("Effective HP" in r for r in check["reasons"])
    compare = witch.call("stats.compare_item", text=WAND)
    assert (
        "warnings" in compare["budget"] and compare["budget"]["effectiveAfter"] >= compare["budget"]["effectiveBefore"]
    )


FOCUS = """Rarity: Rare
Test Focus
Woven Focus
--------
Item Level: 80
--------
50% increased Spell Damage"""


def test_item_check_focus_goes_off_hand(witch):
    # Upstream maps a Focus to a "Focus" slot that does not exist.
    assert witch.check_item(FOCUS)["slot"] == "Weapon 2"


SOCKETED_COAT = """Rarity: RARE
Test Coat
Conjurer Mantle
Item Level: 80
Sockets: S S
Rune: Legacy of Blackbraid
Rune: None
+100 to maximum Life"""


def test_socket_advice_and_plan(witch):
    witch.call("items.equip", text=SOCKETED_COAT, slot="Body Armour")
    advice = witch.socket_advice()
    coat = next(s for s in advice["slots"] if s["slot"] == "Body Armour")
    first, empty = coat["sockets"]
    assert first["current"] == "Legacy of Blackbraid" and "score" in first["worth"]
    assert empty["current"] == "None" and empty["legalOptions"] > 0
    # Another "Legacy of" rune shares Blackbraid's character-wide limit, so it is flagged, not offered as legal.
    blocked = witch.call("sockets.analyze", slot="Body Armour", limit=200)["slots"][0]["sockets"][1]["alternatives"]
    legacies = [a for a in blocked if a["name"].startswith("Legacy of")]
    assert legacies and all(a.get("blockedBy") for a in legacies)
    before = witch.call("stats.get", keys=["TotalEHP", "Life"])
    plan = witch.socket_plan(max_swaps=2)
    assert plan["steps"] and plan["total"]["score"] > 0
    assert witch.call("stats.get", keys=["TotalEHP", "Life"]) == before  # nothing changed


UNNAMED_HEARTWOOD, ANCESTRAL_BOND = 52374, 45202


def test_budget_spell_totem_cap(service):
    # Spell Totem OVERRIDEs the totem limit to 2, which drops Unnamed Heartwood's +1; in game this places 5 (2 x 2 + 1).
    service.new_build("Druid", "Oracle", 90)
    service.call("tree.allocate", ids=[UNNAMED_HEARTWOOD, ANCESTRAL_BOND])
    service.call(
        "skills.add",
        gems=[{"name": "Grim Pillars", "level": 20}, {"name": "Spell Totem", "level": 19, "quality": 20}],
    )
    service.call("config.custom_mods", text="+296 to Spirit")
    budget = service.budget()
    assert budget["ancestralBond"] and budget["spirit"] == 396
    assert (budget["totemCap"], budget["totems"], budget["free"]) == (5, 5, 21)
    # "# of Summoned Totems" can raise the cap; Spirit still limits the totems.
    service.call("config.set", values={"TotemsSummoned": 6})
    budget = service.budget()
    assert (budget["totemCap"], budget["totems"], budget["spiritLimited"]) == (6, 5, True)
    service.call("config.set", values={"TotemsSummoned": 3})
    assert service.budget()["totems"] == 3


def test_reference_rejects_non_build_files(service):
    with pytest.raises(ValueError):
        service.set_reference("not json")
    with pytest.raises(ValueError):
        service.set_reference('{"hello": 1}')


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
    assert all(e[0] in ids and e[1] in ids for e in layout["edges"][:200])
