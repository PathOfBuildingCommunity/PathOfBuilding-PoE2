"""poe.ninja (PoE2) prices and characters, and pathofexile.com trade-site search links.

poe.ninja endpoints used (all public, JSON):
  /poe2/api/data/index-state                          leagues and build snapshot versions
  /poe2/api/economy/stash/current/item/overview       unique prices (primaryValue is in divine orbs)
  /poe2/api/builds/{version}/character                a ladder character's Path of Building export
  /poe2/api/profile/characters/{acc}/{league}/{name}/model/{n}   a profile character's export (n: cache-buster)
"""

from __future__ import annotations

import json
import re
import threading
import time
from typing import Any
from urllib.parse import quote, unquote

import httpx

NINJA = "https://poe.ninja"
TRADE = "https://www.pathofexile.com/trade2/search/poe2"
HEADERS = {"User-Agent": "PoB2-Enhanced (+https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2)"}
UNIQUE_TYPES = ("UniqueWeapons", "UniqueArmours", "UniqueAccessories", "UniqueJewels", "UniqueFlasks", "UniqueCharms")
# Ladder page: /poe2/builds/<league>/character/<account>/<name>
# Profile page: /poe2/profile/<account>/<league>/character/<name>
CHARACTER_URL = re.compile(r"^https?://poe\.ninja/poe2/builds/([\w-]+)/character/([^/?#]+)/([^/?#]+)")
PROFILE_URL = re.compile(r"^https?://poe\.ninja/poe2/profile/([^/?#]+)/([\w-]+)/character/([^/?#]+)")

_cache: dict[str, tuple[float, Any]] = {}
_lock = threading.Lock()


def _get_json(url: str, ttl: float, params: dict[str, str] | None = None, timeout: float = 20.0) -> Any:
    key = url + json.dumps(params or {}, sort_keys=True)
    with _lock:
        hit = _cache.get(key)
        if hit and time.monotonic() - hit[0] < ttl:
            return hit[1]
    resp = httpx.get(url, params=params, headers=HEADERS, timeout=timeout, follow_redirects=True)
    resp.raise_for_status()
    data = resp.json()
    with _lock:
        _cache[key] = (time.monotonic(), data)
    return data


def index_state() -> dict[str, Any]:
    return _get_json(f"{NINJA}/poe2/api/data/index-state", ttl=600)


def leagues() -> list[dict[str, Any]]:
    """Trade/economy leagues, current challenge leagues first."""
    return [
        {"name": lg["name"], "url": lg["url"], "hardcore": lg.get("hardcore", False)}
        for lg in index_state().get("economyLeagues", [])
    ]


def default_league() -> str | None:
    for lg in leagues():
        if not lg["hardcore"]:
            return lg["name"]
    return None


def league_from_slug(slug: str) -> str | None:
    state = index_state()
    for lg in state.get("economyLeagues", []) + state.get("buildLeagues", []) + state.get("snapshotVersions", []):
        if lg.get("url") == slug:
            return lg.get("name")
    return None


def unique_prices(league: str) -> dict[str, Any]:
    """{"rates": {"exalted": n, "chaos": n} per divine, "items": {name: {"divine", "listings", "baseType"}}}."""
    items: dict[str, dict[str, Any]] = {}
    rates: dict[str, float] = {}
    for kind in UNIQUE_TYPES:
        try:
            data = _get_json(
                f"{NINJA}/poe2/api/economy/stash/current/item/overview",
                ttl=1800,
                params={"league": league, "type": kind},
            )
        except httpx.HTTPError:
            continue
        rates = (data.get("core") or {}).get("rates") or rates
        for line in data.get("lines") or []:
            name = line.get("name")
            if not name or line.get("primaryValue") is None:
                continue
            entry = {
                "divine": line["primaryValue"],
                "listings": line.get("listingCount"),
                "baseType": line.get("baseType"),
            }
            # Several variants can share a name; keep the cheapest listing.
            if name not in items or entry["divine"] < items[name]["divine"]:
                items[name] = entry
    return {"rates": rates, "items": items}


def format_price(divine: float, rates: dict[str, float]) -> str:
    if divine >= 1:
        return f"{divine:,.1f} div" if divine < 100 else f"{divine:,.0f} div"
    exalted = divine * (rates.get("exalted") or 0)
    return f"{exalted:,.0f} ex" if exalted else f"{divine:.2f} div"


def trade_url(league: str, query: dict[str, Any]) -> str:
    return f"{TRADE}/{quote(league)}?q={quote(json.dumps(query, separators=(',', ':')))}"


def unique_query(name: str, base: str | None = None) -> dict[str, Any]:
    query: dict[str, Any] = {"status": {"option": "online"}, "name": name}
    if base:
        query["type"] = base
    return {"query": query, "sort": {"price": "asc"}}


def parse_character_url(link: str) -> tuple[str, str, str, str] | None:
    """(kind, league slug, account, name) for a poe.ninja ladder or profile character link."""
    link = link.strip()
    if m := CHARACTER_URL.match(link):
        return "ladder", m.group(1), unquote(m.group(2)), unquote(m.group(3))
    if m := PROFILE_URL.match(link):
        return "profile", m.group(2), unquote(m.group(1)), unquote(m.group(3))
    return None


def is_character_url(link: str) -> bool:
    return parse_character_url(link) is not None


def character_league(link: str) -> str | None:
    parsed = parse_character_url(link)
    return league_from_slug(parsed[1]) if parsed else None


def character_code(link: str) -> tuple[str, str | None]:
    """poe.ninja character page (ladder or profile) -> (PoB share code, league name)."""
    parsed = parse_character_url(link)
    if not parsed:
        raise ValueError("Not a poe.ninja PoE2 character link")
    kind, slug, account, name = parsed
    if kind == "profile":
        # The trailing number only busts poe.ninja's cache (the site uses the character level); any value works.
        path = f"/poe2/api/profile/characters/{quote(account)}/{quote(slug)}/{quote(name)}"
        data = _get_json(f"{NINJA}{path}/model/{int(time.time() // 60)}", ttl=60)
        model = data.get("charModel") or {}
        if data.get("type") != "found" or not model.get("pathOfBuildingExport"):
            raise ValueError("poe.ninja has no public profile data for this character (is the profile public?)")
        return model["pathOfBuildingExport"], league_from_slug(slug)
    snapshot = next((s for s in index_state().get("snapshotVersions", []) if s.get("url") == slug), None)
    if not snapshot:
        raise ValueError(f"poe.ninja has no build snapshot for league '{slug}'")
    data = _get_json(
        f"{NINJA}/poe2/api/builds/{snapshot['version']}/character",
        ttl=60,
        params={
            "account": account,
            "name": name,
            "overview": snapshot["snapshotName"],
            "timeMachine": "",
        },
    )
    code = data.get("pathOfBuildingExport")
    if not code:
        raise ValueError("poe.ninja returned no Path of Building export for this character")
    return code, snapshot.get("name")
