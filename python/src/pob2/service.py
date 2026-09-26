"""High-level, typed operations on a PoB build. Shared by the MCP server, REST API and CLI."""

from __future__ import annotations

import threading
from typing import Any

from pob2 import codec
from pob2.engine import Engine

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
}


class PoBService:
    """Wraps one Engine (one active build) with convenience operations."""

    def __init__(self, engine: Engine | None = None):
        self.engine = engine or Engine()
        self.revision = 0
        self._layout_cache: dict[str, Any] = {}
        self._lock = threading.RLock()

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
        """Load from XML, a share code, or a pobb.in / pastebin / poe.ninja link."""
        xml = codec.resolve(source)
        return self.call("build.load_xml", xml=xml, name=name)

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
        allocated = [n["id"] for n in self.call("tree.get")["nodes"]]
        return {**self._layout_cache[version], "allocated": allocated}
