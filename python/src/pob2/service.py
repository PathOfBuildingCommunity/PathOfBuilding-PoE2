"""High-level, typed operations on a PoB build. Shared by the MCP server, REST API and CLI."""

from __future__ import annotations

import json
import threading
import time
from typing import Any

from pob2 import codec, market
from pob2.engine import Engine, EngineError

# Worker methods that change the build. Used to bump `revision` so UIs can refresh.
MUTATING = {
    "build.new",
    "build.load_xml",
    "build.set_level",
    "build.set_class",
    "skills.add",
    "skills.remove",
    "skills.set_main",
    "skills.set_enabled",
    "items.equip",
    "items.unequip",
    "tree.allocate",
    "tree.deallocate",
    "tree.reset",
    "tree.import_url",
    "config.set",
    "reference.apply_tree",
    "tree.set_attributes",
    "skills.set_gem",
}

# Largest accepted reference .build file (they are typically 20-100 KB).
MAX_REFERENCE_BYTES = 2_000_000


class PoBService:
    """Wraps one Engine (one active build) with convenience operations."""

    def __init__(self, engine: Engine | None = None):
        self.engine = engine or Engine()
        self.revision = 0
        self._layout_cache: dict[str, Any] = {}
        self._lock = threading.RLock()
        # Reference build (PoE2 BuildPlanner .build JSON) the live build is compared against.
        self.reference: dict[str, Any] | None = None
        self._advice_cache: tuple[tuple[Any, ...], dict[str, Any]] | None = None
        # Where the build came from (a link), so it can be re-imported with one click.
        self.source: str | None = None
        self.source_league: str | None = None
        self.source_loaded_at: float | None = None
        self._memo: dict[tuple[Any, ...], Any] = {}

    def call(self, method: str, **params: Any) -> Any:
        result = self.engine.call(method, {k: v for k, v in params.items() if v is not None})
        if method in MUTATING or (method == "config.custom_mods" and params.get("text") is not None):
            self.revision += 1
        return result

    # -- build -----------------------------------------------------------------------------------

    def new_build(
        self,
        class_name: str | None = None,
        ascendancy: str | None = None,
        level: int | None = None,
        name: str | None = None,
    ) -> dict[str, Any]:
        info = self.call("build.new", name=name)
        if class_name or ascendancy:
            info = self.call("build.set_class", className=class_name, ascendClassName=ascendancy)
        if level:
            info = self.call("build.set_level", level=level)
        return info

    def set_character(
        self, level: int | None = None, class_name: str | None = None, ascendancy: str | None = None
    ) -> dict[str, Any]:
        info = None
        if class_name or ascendancy:
            info = self.call("build.set_class", className=class_name, ascendClassName=ascendancy)
        if level:
            info = self.call("build.set_level", level=level)
        return info or self.info()

    def load(self, source: str, name: str | None = None) -> dict[str, Any]:
        """Load from XML, a share code, or a pobb.in / pastebin / poe.ninja link (paste or character page)."""
        xml = codec.resolve(source)
        info = self.call("build.load_xml", xml=xml, name=name)
        link = source.strip()
        if link.startswith(("http://", "https://")):
            self.source = link
            try:
                self.source_league = market.character_league(link)
            except Exception:  # noqa: BLE001 - league lookup is a convenience
                self.source_league = None
        else:
            self.source = self.source_league = None
        self.source_loaded_at = time.time()
        return info

    def source_info(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "character": bool(self.source and market.is_character_url(self.source)),
            "league": self.source_league,
            "loadedAt": self.source_loaded_at,
        }

    def refresh(self) -> dict[str, Any]:
        """Re-import the build from its source link, keeping the Config tab settings."""
        if not self.source:
            raise ValueError("This build wasn't imported from a link, so there is nothing to refresh from")
        keys = ["TotalDPS", "CombinedDPS", "Life", "EnergyShield", "TotalEHP"]
        before = self.call("stats.get", keys=keys)
        config = {
            c["var"]: c["value"]
            for c in self.call("config.list", all=True)
            if c.get("value") is not None and c.get("value") != c.get("default")
        }
        info = self.load(self.source)
        if config:
            try:
                self.call("config.set", values=config)
            except EngineError:
                pass  # options that no longer apply to the refreshed build
        after = self.call("stats.get", keys=keys)
        return {"info": info, "before": before, "after": after, "source": self.source_info()}

    def export(self) -> dict[str, str]:
        xml = self.call("build.export_xml")["xml"]
        return {"code": codec.encode_code(xml), "xml": xml}

    def info(self) -> dict[str, Any]:
        return self.call("build.info")

    def overview(self) -> dict[str, Any]:
        """Everything needed to understand the build in one call."""
        items = self.call("items.list", full=False)
        config = self.call("config.list")
        return {
            "info": self.info(),
            "stats": self.call("stats.summary"),
            "skills": self.call("skills.list"),
            "items": [
                {"slot": i["slot"], "name": i["item"]["name"], "rarity": i["item"]["rarity"]}
                for i in items
                if i.get("item")
            ],
            "config": {
                c["var"]: c["value"]
                for c in config
                if c.get("value") is not None and c.get("value") != c.get("default")
            },
        }

    # -- reference build ---------------------------------------------------------------------------

    def set_reference(self, content: str | dict[str, Any]) -> dict[str, Any]:
        """Store a PoE2 BuildPlanner (.build) guide to compare the live build against."""
        if isinstance(content, str):
            if len(content.encode("utf-8")) > MAX_REFERENCE_BYTES:
                raise ValueError("Reference file is too large")
            try:
                ref = json.loads(content.lstrip("﻿"))
            except json.JSONDecodeError as e:
                raise ValueError(f"Not a .build file (invalid JSON: {e.msg})") from e
        else:
            ref = content
        sections = ("passives", "skills", "inventory_slots")
        if not isinstance(ref, dict) or not any(isinstance(ref.get(k), list) for k in sections):
            raise ValueError("Not a PoE2 BuildPlanner .build file (no passives, skills or inventory_slots)")
        self.reference = ref
        self.revision += 1
        return self.reference_summary()

    def clear_reference(self) -> None:
        self.reference = None
        self.revision += 1

    def _require_reference(self) -> dict[str, Any]:
        if self.reference is None:
            raise ValueError("No reference build loaded")
        return self.reference

    def reference_summary(self) -> dict[str, Any] | None:
        ref = self.reference
        if ref is None:
            return None
        return {
            "name": ref.get("name"),
            "author": ref.get("author"),
            "link": ref.get("link"),
            "ascendancy": ref.get("ascendancy"),
            "passives": len(ref.get("passives") or []),
            "skills": len(ref.get("skills") or []),
            "items": len(ref.get("inventory_slots") or []),
        }

    def reference_compare(self, level: int | None = None) -> dict[str, Any]:
        """Passive, skill and gear differences between the live build and the reference at a level."""
        return self.call("reference.compare", reference=self._require_reference(), level=level)

    def reference_impact(self, level: int | None = None, limit: int | None = None) -> dict[str, Any]:
        """Stat impact of the reference tree, ranked next steps and the value of extra nodes."""
        return self.call("reference.impact", reference=self._require_reference(), level=level, limit=limit)

    def apply_reference_tree(self, level: int | None = None) -> dict[str, Any]:
        return self.call("reference.apply_tree", reference=self._require_reference(), level=level)

    # -- advisor -------------------------------------------------------------------------------------

    def advice(self, metric: str = "balanced", level: int | None = None, limit: int | None = None) -> dict[str, Any]:
        """Next passive point, which point to move, and attribute node choices (follows the reference if loaded)."""
        key = (self.revision, id(self.reference), metric, level, limit)
        with self._lock:
            if self._advice_cache and self._advice_cache[0] == key:
                return self._advice_cache[1]
        result = self.call("advisor.plan", reference=self.reference, metric=metric, level=level, limit=limit)
        with self._lock:
            self._advice_cache = (key, result)
        return result

    def set_attributes(self, changes: list[dict[str, Any]]) -> dict[str, Any]:
        """Choose +5 Strength/Dexterity/Intelligence on attribute nodes: [{"id": 123, "attribute": "Strength"}]."""
        return self.call("tree.set_attributes", changes=changes)

    # -- spirit / totem budget -------------------------------------------------------------------------

    def budget(self) -> dict[str, Any]:
        """Spirit total/reserved/free, totems affordable vs cap, and main-skill DPS across all totems."""
        return self.call("budget.get")

    def check_item(self, text: str, slot: str | None = None) -> dict[str, Any]:
        """Check before you buy: verdict, every damage skill (totems counted), Spirit/totems, defences, requirements."""
        return self.call("budget.check_item", text=text, slot=slot)

    # -- gear, shopping and gems ---------------------------------------------------------------------

    def _memoised(self, key: tuple[Any, ...], fn: Any) -> Any:
        """Cache an engine result for the current build revision."""
        full = (self.revision, *key)
        with self._lock:
            if full in self._memo:
                return self._memo[full]
        result = fn()
        with self._lock:
            self._memo = {k: v for k, v in self._memo.items() if k[0] == self.revision}
            self._memo[full] = result
        return result

    def league(self, league: str | None = None) -> str | None:
        if league:
            return league
        if self.source_league:
            return self.source_league
        try:
            return market.default_league()
        except Exception:  # noqa: BLE001 - poe.ninja unreachable; links just won't have a league
            return None

    def gear_slots(self) -> list[dict[str, Any]]:
        return self._memoised(("gear.slots",), lambda: self.call("gear.slots"))

    def gear_slot(self, slot: str, metric: str = "balanced", league: str | None = None) -> dict[str, Any]:
        """What the item in a slot and each of its mods is worth, what to look for, and a weighted trade search."""
        cached = self._memoised(("gear.slot", slot, metric), lambda: self.call("gear.slot", slot=slot, metric=metric))
        result = dict(cached)
        league = self.league(league)
        if league and result.get("tradeQuery"):
            result["tradeUrl"] = market.trade_url(league, result["tradeQuery"])
            result["league"] = league
        return result

    def gear_overview(self, metric: str = "balanced", league: str | None = None) -> list[dict[str, Any]]:
        """Every slot's analysis, best upgrade opportunity first."""
        rows = [self.gear_slot(s["slot"], metric, league) for s in self.gear_slots()]
        return sorted(rows, key=lambda r: r.get("headroom") or 0, reverse=True)

    def gear_uniques(
        self, metric: str = "balanced", league: str | None = None, max_price: float | None = None
    ) -> dict[str, Any]:
        """Uniques that would help most per slot, with poe.ninja prices and trade links."""
        groups = self._memoised(("gear.uniques", metric), lambda: self.call("gear.uniques", metric=metric, limit=25))
        league = self.league(league)
        prices: dict[str, Any] = {"rates": {}, "items": {}}
        if league:
            try:
                prices = market.unique_prices(league)
            except Exception:  # noqa: BLE001 - prices are optional
                pass
        out = []
        for group in groups:
            items = []
            for item in group["items"]:
                row = dict(item)
                price = prices["items"].get(item["name"])
                if price:
                    row["priceDivine"] = price["divine"]
                    row["price"] = market.format_price(price["divine"], prices["rates"])
                    row["listings"] = price["listings"]
                    if price["divine"] > 0:
                        row["gainPerDivine"] = item["score"] / price["divine"]
                if max_price is not None and row.get("priceDivine") is not None and row["priceDivine"] > max_price:
                    continue
                if league:
                    row["tradeUrl"] = market.trade_url(league, market.unique_query(item["name"], item.get("baseName")))
                items.append(row)
            if items:
                out.append({"slot": group["slot"], "items": items[:8]})
        return {"league": league, "rates": prices["rates"], "slots": out}

    def gems_advice(self, metric: str = "balanced") -> dict[str, Any]:
        """Support worth, best replacement per skill, gem level/quality upgrades and setup problems."""
        return self._memoised(("gems.advise", metric), lambda: self.call("gems.advise", metric=metric))

    def socket_advice(self, metric: str = "balanced", slot: str | None = None, limit: int = 5) -> dict[str, Any]:
        """Each socketed rune/soul core/idol's worth and the best legal replacements per socket."""
        return self._memoised(
            ("sockets.analyze", metric, slot, limit),
            lambda: self.call("sockets.analyze", metric=metric, slot=slot, limit=limit),
        )

    def socket_plan(
        self, metric: str = "balanced", max_swaps: int = 8, min_gain: float = 0.5, keep_unmodelled: bool = True
    ) -> dict[str, Any]:
        """Greedy combined plan of socket swaps, re-measured after each one. Does not change the build."""
        return self._memoised(
            ("sockets.optimize", metric, max_swaps, min_gain, keep_unmodelled),
            lambda: self.call(
                "sockets.optimize", metric=metric, maxSwaps=max_swaps, minGain=min_gain, keepUnmodelled=keep_unmodelled
            ),
        )

    def set_gem(self, group: int, index: int, **changes: Any) -> dict[str, Any]:
        return self.call("skills.set_gem", group=group, index=index, **changes)

    # -- tree ------------------------------------------------------------------------------------

    def tree_layout(self) -> dict[str, Any]:
        """Static node geometry (cached per tree version) plus the current allocation."""
        info = self.info()
        version = info["treeVersion"]
        with self._lock:
            if version not in self._layout_cache:
                layout = self.call("tree.layout")
                for node in layout["nodes"]:
                    node.pop("alloc", None)
                self._layout_cache[version] = layout
        tree = self.call("tree.get")
        allocated = [n["id"] for n in tree["nodes"]]
        # Chosen +5 attribute on allocated attribute nodes (Strength/Dexterity/Intelligence).
        attributes = {str(n["id"]): n["name"] for n in tree["nodes"] if n.get("isAttribute")}
        jewels = {
            str(i["jewelNodeId"]): {
                k: i["item"].get(k) for k in ("name", "title", "baseName", "rarity", "mods") if i["item"].get(k)
            }
            for i in self.call("items.list", full=True)
            if i.get("jewelNodeId") and i.get("item")
        }
        return {
            **self._layout_cache[version],
            "allocated": allocated,
            "jewels": jewels,
            "attributes": attributes,
            "className": tree.get("className"),
            "ascendClassName": tree.get("ascendClassName"),
        }
